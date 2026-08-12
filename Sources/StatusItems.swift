import AppKit

/// メニューバーに並ぶ項目ひとつ。
struct StatusItem {
    /// 画面ごとに別の値を持つ。板との対応付けに使う。再起動で変わるので保存には使えない。
    let windowID: CGWindowID
    /// 割り当ての鍵。`io.kkweb.konechi#0` のような形。識別できないときは空。
    let key: String
    /// CoreGraphics 座標。原点は主ディスプレイの左上。
    let frame: CGRect
}

enum StatusItems {
    /// ステータス項目はこの層に住んでいる。
    private static let statusLayer = 25

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.first { CGDisplayBounds(displayID(of: $0)).intersects(frame) }
    }

    /// CoreGraphics 座標を AppKit のスクリーン座標へ。画面ごとに上端からの距離で測る。
    static func toAppKit(_ frame: CGRect) -> CGRect {
        guard let host = screen(containing: frame) else { return frame }
        let offsetFromTop = frame.maxY - CGDisplayBounds(displayID(of: host)).minY
        return CGRect(x: frame.minX, y: host.frame.maxY - offsetFromTop,
                      width: frame.width, height: frame.height)
    }

    /// 画面に出ている項目を、タイトルは生のまま拾う。
    private static func raw() -> [StatusItem] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let myPID = ProcessInfo.processInfo.processIdentifier

        return list.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == statusLayer,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != myPID,
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            // メニューバー全体を覆う板や、極端に細いものは項目ではない。
            guard frame.height < 60, frame.width > 4, frame.width < 200 else { return nil }
            // その画面の上端に貼り付いているものだけ。
            guard let host = screen(containing: frame),
                  frame.minY - CGDisplayBounds(displayID(of: host)).minY < 5
            else { return nil }
            let title = info[kCGWindowName as String] as? String ?? ""
            return StatusItem(windowID: windowID, key: title, frame: frame)
        }
    }

    /// タイトルの見込みの良さ。画面によって付き方が違うので、良いほうを採る。
    private static func titleScore(_ title: String) -> Int {
        if title.isEmpty { return 0 }
        if title.hasPrefix("Item-") { return 1 }  // どのアプリか分からない汎用名
        if title.contains(".") { return 3 }       // バンドル ID とみなす
        return 2                                  // Battery や UserSwitcher のような固有名
    }

    /// 鍵まで解決した項目を返す。
    ///
    /// 画面によってタイトルの付き方が違い、片方でバンドル ID が入る位置が、
    /// もう片方では空だったり `Item-0` だったりする。右端からの並び順と幅は
    /// 画面をまたいで一致するので、突き合わせて良いほうの名前を採る。
    static func resolved() -> [StatusItem] {
        var byDisplay: [CGDirectDisplayID: [StatusItem]] = [:]
        var occupied: Set<String> = []
        // 一覧は前面から順に並ぶ。同じ位置に複数のウィンドウを持つアプリがあるので、
        // 前面のものだけを残す。残さないと同じ項目が二重に数えられ、
        // 通し番号がずれて割り当てが外れる。
        for item in raw() {
            guard let host = screen(containing: item.frame) else { continue }
            let display = displayID(of: host)
            let spot = "\(display)|\(Int(item.frame.minX))|\(Int(item.frame.width))"
            guard occupied.insert(spot).inserted else { continue }
            byDisplay[display, default: []].append(item)
        }
        let lists = byDisplay.values.map { $0.sorted { $0.frame.minX > $1.frame.minX } }

        // 右端から数えた位置ごとに、各画面の名前を持ち寄って最良を選ぶ。
        var bestTitle: [Int: String] = [:]
        for index in 0..<(lists.map(\.count).max() ?? 0) {
            let candidates = lists.compactMap { index < $0.count ? $0[index] : nil }
            // 同点のときは長いほうを採る。`Doll_com.hnc.Discord` のように
            // 何のための項目かまで入っている名前のほうが特定できる。
            // 最後に辞書順で並べ、実行ごとに結果が変わらないようにする。
            guard let best = candidates.min(by: { left, right in
                let leftScore = titleScore(left.key), rightScore = titleScore(right.key)
                if leftScore != rightScore { return leftScore > rightScore }
                if left.key.count != right.key.count { return left.key.count > right.key.count }
                return left.key < right.key
            }) else { continue }
            // 幅が食い違う位置は並びがずれている。名前は写さない。
            guard candidates.allSatisfy({ $0.frame.width == best.frame.width }) else { continue }
            bestTitle[index] = best.key
        }

        // 同じアプリが複数の項目を持つので、通し番号を足して鍵にする。
        // 番号はウィンドウ ID の昇順、つまりアプリが項目を作った順。
        var resolved: [StatusItem] = []
        for items in lists {
            let titled = items.enumerated().map { index, item in
                StatusItem(windowID: item.windowID, key: bestTitle[index] ?? item.key, frame: item.frame)
            }
            var counters: [String: Int] = [:]
            var keyByWindow: [CGWindowID: String] = [:]
            for item in titled.sorted(by: { $0.windowID < $1.windowID }) where !item.key.isEmpty {
                let number = counters[item.key, default: 0]
                counters[item.key] = number + 1
                keyByWindow[item.windowID] = "\(item.key)#\(number)"
            }
            resolved += titled.map {
                StatusItem(windowID: $0.windowID, key: keyByWindow[$0.windowID] ?? "", frame: $0.frame)
            }
        }
        return resolved
    }
}
