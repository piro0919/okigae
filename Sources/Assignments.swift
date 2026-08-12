import AppKit

/// どの項目にどの絵を当てるか。
///
/// 鍵は `StatusItems.resolved()` が返すもので、`io.kkweb.konechi#0` のような形。
/// ウィンドウ ID は再起動で変わるため使えず、バンドル ID だけでは同じアプリが
/// 複数の項目を出す場合に区別できないので、通し番号を足している。
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

    static func prepareDirectories() {
        for directory in [supportDirectory, charactersDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        migrateFacesFolder()
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
    static func installBundledFaces() {
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
        installBundledFaces()
        cache.removeAll()
        guard let data = try? Data(contentsOf: file),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            table = [:]
            return
        }
        table = parsed
    }

    static func save() {
        prepareDirectories()
        guard let data = try? JSONSerialization.data(withJSONObject: table,
                                                     options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? data.write(to: file)
    }

    static func set(character: String?, for key: String) {
        table[key] = character
        save()
    }

    /// 鍵に対応するキャラクター。無ければ nil。
    static func image(for key: String) -> NSImage? {
        guard let name = table[key] else { return nil }
        if let cached = cache[name] { return cached }
        let url = charactersDirectory.appendingPathComponent("\(name).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }

    /// Characters に置かれているキャラクターの一覧。
    static func availableCharacters() -> [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: charactersDirectory.path)) ?? []
        return contents
            .filter { $0.hasSuffix(".png") }
            .map { String($0.dropLast(4)) }
            .sorted()
    }
}
