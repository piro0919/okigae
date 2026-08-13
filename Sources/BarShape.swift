import AppKit

/// メニューバーの帯の高さを測る。
///
/// Ice のようにメニューバーの見た目を変えるアプリは、角の丸い帯を描いて
/// 上下を少し詰める。板が項目の矩形をそのまま覆うと、その差が切れ目に見える。
/// 項目が無い列を一本撮って、帯が始まる位置と終わる位置を読み取れば、
/// 板の上下に取るべき余白が決まる。何も重なっていなければ 0 になる。
enum BarShape {
    /// 上下に取る余白。ポイント。
    private(set) static var inset: CGFloat = 0

    private static var measuredAt: CFAbsoluteTime = 0
    private static let interval: CFAbsoluteTime = 15

    static var isStale: Bool { CFAbsoluteTimeGetCurrent() - measuredAt > interval }

    /// 手で入れた値があればそれを使う。無ければ測った値。
    static var effective: CGFloat {
        if let manual = UserDefaults.standard.object(forKey: "verticalInset") as? Double {
            return CGFloat(manual)
        }
        return inset
    }

    /// 項目の間の隙間を一つ選び、そこの縦一列を読む。
    static func measure(items: [StatusItem]) {
        measuredAt = CFAbsoluteTimeGetCurrent()
        guard let screen = NSScreen.main else { return }

        let bounds = CGDisplayBounds(StatusItems.displayID(of: screen))
        let onScreen = items.filter { bounds.intersects($0.frame) }.sorted { $0.frame.minX < $1.frame.minX }
        guard let height = onScreen.first?.frame.height, height > 8 else { return }

        // 項目と項目の間で、幅が 2 ポイント以上ある隙間を探す
        var gapX: CGFloat?
        for (left, right) in zip(onScreen, onScreen.dropFirst()) where right.frame.minX - left.frame.maxX >= 2 {
            gapX = (left.frame.maxX + right.frame.minX) / 2
            break
        }
        guard let x = gapX else { return }

        let column = CGRect(x: x, y: bounds.minY, width: 1, height: height)
        guard let image = Backdrop.captureScreen(region: column) else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard bitmap.pixelsHigh > 4 else { return }

        let scale = CGFloat(bitmap.pixelsHigh) / height
        guard let middle = bitmap.colorAt(x: 0, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB) else { return }

        func differs(_ y: Int) -> Bool {
            guard let color = bitmap.colorAt(x: 0, y: y)?.usingColorSpace(.sRGB) else { return false }
            let distance = abs(color.redComponent - middle.redComponent)
                + abs(color.greenComponent - middle.greenComponent)
                + abs(color.blueComponent - middle.blueComponent)
            return distance > 0.12
        }

        // 上端から、帯の色と違う行が続く分を数える
        var top = 0
        while top < bitmap.pixelsHigh / 2, differs(top) { top += 1 }
        var bottom = 0
        while bottom < bitmap.pixelsHigh / 2, differs(bitmap.pixelsHigh - 1 - bottom) { bottom += 1 }

        let measured = CGFloat(max(top, bottom)) / scale
        // 極端な値は測り損ねとみなす
        inset = measured < height / 3 ? measured.rounded() : 0
    }
}
