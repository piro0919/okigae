import Foundation

/// 画面を出さずに、引き当てだけを確かめる。`./Okigae --selftest` で走る。
/// 保存された割り当て表にも Characters の中身にも触らない。
@MainActor
enum SelfTest {

    private static var failures = 0

    static func run() -> Int32 {
        failures = 0

        // 項目に対応するキャラクターの引き当て
        do {
            let table = ["wifi": "momoka", "com.apple.wifi": "ruri"]

            check(
                Assignments.character(for: "wifi", aliases: [], in: table) == "momoka",
                "自分の鍵で見つかる")
            check(
                Assignments.character(for: "unknown", aliases: [], in: table) == nil,
                "割り当てが無ければ nil")

            // 同じ項目が画面によって別の名前を名乗るので、別名も見に行く
            check(
                Assignments.character(
                    for: "unknown", aliases: ["com.apple.wifi"],
                    in: table) == "ruri",
                "自分の鍵で駄目なら別名を見る")

            // 自分の鍵を先に見る。別名が先に当たると、画面ごとに違う絵が出る
            check(
                Assignments.character(
                    for: "wifi", aliases: ["com.apple.wifi"],
                    in: table) == "momoka",
                "自分の鍵が別名より優先される")

            check(
                Assignments.character(
                    for: "x", aliases: ["y", "com.apple.wifi"],
                    in: table) == "ruri",
                "別名は並べた順に見る")
            check(
                Assignments.character(for: "x", aliases: ["y", "z"], in: [:]) == nil,
                "表が空なら nil")
        }

        // 升目に出す名前
        do {
            check(
                Assignments.displayName(for: "momoka", japanese: true) == "ももか",
                "同梱の絵は日本語ではかなで出す")
            check(
                Assignments.displayName(for: "momoka", japanese: false) == "momoka",
                "英語ではファイル名のまま出す")

            // 利用者が自分で置いた絵は、ファイル名がそのまま名前になる
            check(
                Assignments.displayName(for: "my-own-face", japanese: true) == "my-own-face",
                "読みの無い名前はそのまま出す")
        }

        // 同梱キャラクターの名前の対応表
        do {
            // 改名先に読みが無いと、升目にローマ字が出てしまう
            let missing = Assignments.renamed.values.filter { Assignments.readings[$0] == nil }
            check(missing.isEmpty, "改名した先にはすべて読みがある")

            // 古い名前が読みの表に残っていると、改名前の名前でも引けてしまう
            let stale = Assignments.renamed.keys.filter { Assignments.readings[$0] != nil }
            check(stale.isEmpty, "改名前の名前は読みの表に残っていない")

            check(
                Set(Assignments.renamed.values).count == Assignments.renamed.count,
                "改名先が重なっていない")
        }

        // 割り当て表の読み書き。一時フォルダで試し、本物の assignments.json には触らない
        do {
            let manager = FileManager.default
            let directory = manager.temporaryDirectory
                .appendingPathComponent("okigae-selftest-\(UUID().uuidString)", isDirectory: true)
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: directory) }
            let file = directory.appendingPathComponent("assignments.json")

            check(Assignments.readTable(from: file).isEmpty, "ファイルが無ければ空の表")
            check(
                (try? manager.contentsOfDirectory(atPath: directory.path))?.isEmpty == true,
                "ファイルが無いときは何も作らない")

            let table = ["wifi#0": "momoka", "Clock#0": "ruri"]
            check(Assignments.write(table, to: file), "書き出せる")
            check(Assignments.readTable(from: file) == table, "書いた表をそのまま読める")

            // 壊れたファイルは空として読むが、上書きされる前に退避されていなければならない
            let broken = Data("{\"wifi#0\": \"momo".utf8)
            try? broken.write(to: file)
            let stamp = Date(timeIntervalSince1970: 1_800_000_000)
            check(Assignments.readTable(from: file, now: stamp).isEmpty, "壊れた表は空として読む")
            check(!manager.fileExists(atPath: file.path), "壊れたファイルは元の場所から退く")
            let names = (try? manager.contentsOfDirectory(atPath: directory.path)) ?? []
            let backups = names.filter { $0.hasPrefix("assignments.json.corrupt-") }
            check(backups.count == 1, "壊れたファイルは .corrupt-<日時> に残る")
            check(
                backups.first.flatMap {
                    try? Data(contentsOf: directory.appendingPathComponent($0))
                } == broken,
                "退避したファイルの中身は元のまま")

            // 形は JSON でも、文字列から文字列への表でなければ同じく退避する
            try? Data("[1, 2, 3]".utf8).write(to: file)
            check(Assignments.readTable(from: file, now: stamp).isEmpty, "型の違う JSON も空として読む")
            let after = ((try? manager.contentsOfDirectory(atPath: directory.path)) ?? [])
                .filter { $0.hasPrefix("assignments.json.corrupt-") }
            check(after.count == 2, "同じ時刻に壊れても前の退避を上書きしない")

            // 書き出しに失敗しても落ちずに false を返す
            let unwritable = directory.appendingPathComponent("missing/assignments.json")
            check(!Assignments.write(table, to: unwritable), "書けない場所では false を返す")
        }

        print(failures == 0 ? "全部通りました" : "\(failures) 件こけました")
        return failures == 0 ? 0 : 1
    }

    private static func check(_ condition: Bool, _ what: String) {
        if condition {
            print("  ok   \(what)")
        } else {
            print("  NG   \(what)")
            failures += 1
        }
    }
}
