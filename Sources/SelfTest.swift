import Foundation

/// 画面を出さずに、引き当てだけを確かめる。`./Okigae --selftest` で走る。
/// 保存された割り当て表にも Characters の中身にも触らない。
enum SelfTest {

    private static var failures = 0

    static func run() -> Int32 {
        failures = 0

        // 項目に対応するキャラクターの引き当て
        do {
            let table = ["wifi": "momoka", "com.apple.wifi": "ruri"]

            check(Assignments.character(for: "wifi", aliases: [], in: table) == "momoka",
                  "自分の鍵で見つかる")
            check(Assignments.character(for: "unknown", aliases: [], in: table) == nil,
                  "割り当てが無ければ nil")

            // 同じ項目が画面によって別の名前を名乗るので、別名も見に行く
            check(Assignments.character(for: "unknown", aliases: ["com.apple.wifi"],
                                        in: table) == "ruri",
                  "自分の鍵で駄目なら別名を見る")

            // 自分の鍵を先に見る。別名が先に当たると、画面ごとに違う絵が出る
            check(Assignments.character(for: "wifi", aliases: ["com.apple.wifi"],
                                        in: table) == "momoka",
                  "自分の鍵が別名より優先される")

            check(Assignments.character(for: "x", aliases: ["y", "com.apple.wifi"],
                                        in: table) == "ruri",
                  "別名は並べた順に見る")
            check(Assignments.character(for: "x", aliases: ["y", "z"], in: [:]) == nil,
                  "表が空なら nil")
        }

        // 升目に出す名前
        do {
            check(Assignments.displayName(for: "momoka") == "ももか", "同梱の絵はかなで出す")

            // 利用者が自分で置いた絵は、ファイル名がそのまま名前になる
            check(Assignments.displayName(for: "my-own-face") == "my-own-face",
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

            check(Set(Assignments.renamed.values).count == Assignments.renamed.count,
                  "改名先が重なっていない")
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
