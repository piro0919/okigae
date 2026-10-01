import AppKit
import os

private let log = Logger(subsystem: "io.kkweb.okigae", category: "assignments")

/// どの項目にどの絵を当てるか。
///
/// 鍵は `StatusItems.resolved()` が返すもので、`io.kkweb.konechi#0` のような形。
/// ウィンドウ ID は再起動で変わるため使えず、バンドル ID だけでは同じアプリが
/// 複数の項目を出す場合に区別できないので、通し番号を足している。
@MainActor
enum Assignments {
    /// 設定と絵の置き場。
    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Okigae", isDirectory: true)
    }()

    static var charactersDirectory: URL { supportDirectory.appendingPathComponent("Characters", isDirectory: true) }
    static var file: URL { supportDirectory.appendingPathComponent("assignments.json") }

    /// 鍵からキャラクターの名前への対応。絵は Characters/<名前>.png に置く。
    private(set) static var table: [String: String] = [:]

    private static var cache: [String: NSImage] = [:]

    /// 同梱キャラクターの、色で呼んでいたころの名前と今の名前。
    ///
    /// ファイル名がそのまま鍵であり、画面に出る名前でもある。名前を変えるということは
    /// ファイルを改名することで、配った先の `assignments.json` には古い名前が
    /// 書かれたまま残る。読み込みのたびに一度だけ突き合わせて直す。
    static let renamed: [String: String] = [
        "pink": "momoka", "blue": "ruri", "green": "konoha", "orange": "hinata",
        "red": "akane", "purple": "sumire", "black": "kuroha", "silver": "yuki",
    ]

    /// 同梱キャラクターの読み。ファイル名はローマ字だが、画面にはかなで出す。
    /// ここに無い名前 — 利用者が自分で置いた絵 — はファイル名のまま出す。
    static let readings: [String: String] = [
        "momoka": "ももか", "ruri": "るり", "konoha": "このは", "hinata": "ひなた",
        "akane": "あかね", "sumire": "すみれ", "kuroha": "くろは", "yuki": "ゆき",
        "himari": "ひまり",
        "mio": "みお",
    ]

    /// 升目に出す名前。
    /// かなの読みは日本語の画面でだけ使う。英語ではファイル名のまま出す。
    static func displayName(for character: String, japanese: Bool? = nil) -> String {
        guard japanese ?? (Language.resolved == .ja) else { return character }
        return readings[character] ?? character
    }

    static func prepareDirectories() {
        for directory in [supportDirectory, charactersDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        migrateFacesFolder()
        migrateCharacterNames()
    }

    /// 色の名前で置かれた絵を、新しい名前へ改名する。
    ///
    /// 同梱の絵を差し替えて使っている人がいるので、消して置き直すのではなく動かす。
    /// 新しい名前が既にあるなら触らない。利用者が同じ名前の絵を置いている場合に、
    /// それを上書きしてしまう。
    ///
    /// `installBundledCharacters` より先に走る必要がある。後だと新しい名前の絵が
    /// 先に置かれ、改名が飛ばされて、古い名前の絵が一覧に残り続ける。
    private static func migrateCharacterNames() {
        let manager = FileManager.default
        for (old, new) in renamed {
            let from = charactersDirectory.appendingPathComponent("\(old).png")
            let to = charactersDirectory.appendingPathComponent("\(new).png")
            guard manager.fileExists(atPath: from.path), !manager.fileExists(atPath: to.path) else { continue }
            try? manager.moveItem(at: from, to: to)
        }
    }

    /// 以前は Faces という名前だった。見つけたら中身を移す。
    private static func migrateFacesFolder() {
        let old = supportDirectory.appendingPathComponent("Faces", isDirectory: true)
        guard FileManager.default.fileExists(atPath: old.path),
            let names = try? FileManager.default.contentsOfDirectory(atPath: old.path)
        else { return }
        for name in names {
            let destination = charactersDirectory.appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            try? FileManager.default.moveItem(at: old.appendingPathComponent(name), to: destination)
        }
        try? FileManager.default.removeItem(at: old)
    }

    /// 同梱のキャラクターを Characters へ書き出す。同じ名前が既にあれば触らない。
    ///
    /// 配布した相手の環境には何も無いので、初回は選べる絵が一つも無い状態から始まる。
    /// アプリの中に 8 体持たせて、初回起動で置く。
    static func installBundledCharacters() {
        prepareDirectories()
        guard let bundled = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "Characters") else {
            return
        }
        for source in bundled {
            let destination = charactersDirectory.appendingPathComponent(source.lastPathComponent)
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            try? FileManager.default.copyItem(at: source, to: destination)
        }
    }

    static func load() {
        prepareDirectories()
        installBundledCharacters()
        cache.removeAll()
        let parsed = readTable(from: file)
        // 古い名前で書かれた割り当ては、絵が改名済みなら行き先を失っている。
        let repaired = parsed.mapValues { value -> String in
            guard let new = renamed[value],
                FileManager.default.fileExists(
                    atPath: charactersDirectory.appendingPathComponent("\(new).png").path)
            else { return value }
            return new
        }
        table = repaired
        if repaired != parsed { save() }
    }

    /// 割り当て表を読む。無ければ空。
    ///
    /// 読めない・壊れているときも空で返すが、その前にファイルを
    /// `assignments.json.corrupt-<日時>` へ退避する。空の表のまま次の `save()` が走ると、
    /// 壊れていただけの設定が跡形もなく上書きされる。手で直せる余地を残す。
    nonisolated static func readTable(from url: URL, now: Date = Date()) -> [String: String] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return [:] }
        if let data = try? Data(contentsOf: url),
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        {
            return parsed
        }
        let backup = corruptBackupURL(for: url, at: now)
        do {
            try manager.moveItem(at: url, to: backup)
            log.error(
                "assignments.json を読めないので退避しました: \(backup.path, privacy: .public)")
        } catch {
            log.error(
                "assignments.json を読めず、退避にも失敗しました: \(error.localizedDescription, privacy: .public)"
            )
        }
        return [:]
    }

    /// 退避先。同じ秒に二度壊れることはまず無いが、あれば番号を足して上書きを避ける。
    nonisolated static func corruptBackupURL(for url: URL, at date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: date)
        var candidate = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)-\(number)")
            number += 1
        }
        return candidate
    }

    static func save() {
        prepareDirectories()
        write(table, to: file)
    }

    /// 書き出す。途中で落ちても半端なファイルを残さないよう、一時ファイル経由で置き換える。
    @discardableResult
    nonisolated static func write(_ table: [String: String], to url: URL) -> Bool {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: table,
                options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            log.error(
                "assignments.json を書けませんでした: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 割り当てる。別の画面で同じ項目が名乗る鍵にも同じ値を書く。
    ///
    /// 書き分けると、画面ごとに違う顔が出る状態を作れてしまう。同じ項目である以上
    /// 一つの答えしか無いので、まとめて同じ値にする。
    static func set(character: String?, for key: String, aliases: [String] = []) {
        for target in [key] + aliases {
            table[target] = character
        }
        save()
    }

    /// 項目に対応するキャラクター。自分の鍵で見つからなければ、
    /// 同じ項目が別の画面で名乗る鍵も見る。
    static func character(for key: String, aliases: [String]) -> String? {
        character(for: key, aliases: aliases, in: table)
    }

    /// 引き当ての中身。割り当て表を渡せるようにして、保存された表に触らずに
    /// 確かめられるようにしている。自分の鍵を先に見るので、別名より優先される。
    static func character(
        for key: String, aliases: [String],
        in table: [String: String]
    ) -> String? {
        for candidate in [key] + aliases {
            if let name = table[candidate] { return name }
        }
        return nil
    }

    static func image(for key: String, aliases: [String]) -> NSImage? {
        guard let name = character(for: key, aliases: aliases) else { return nil }
        return image(named: name)
    }

    /// 鍵に対応するキャラクター。無ければ nil。
    static func image(for key: String) -> NSImage? {
        guard let name = table[key] else { return nil }
        return image(named: name)
    }

    private static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let url = charactersDirectory.appendingPathComponent("\(name).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }

    /// Characters に置かれているキャラクターの一覧。
    static func availableCharacters() -> [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: charactersDirectory.path)) ?? []
        return
            contents
            .filter { $0.hasSuffix(".png") }
            .map { String($0.dropLast(4)) }
            .sorted()
    }
}
