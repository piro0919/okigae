import AppKit

/// メニューバーの帯の高さを測る。
///
/// Ice のようにメニューバーの見た目を変えるアプリは、角の丸い帯を描いて
/// 上下を少し詰める。板が項目の矩形をそのまま覆うと、その差が切れ目に見える。
/// 縦一列を読んで、帯が始まる位置と終わる位置を数えれば、板の上下に取るべき
/// 余白が決まる。何も重なっていなければ 0 になる。
///
/// 余白は画面ごとに違う。内蔵ディスプレイのメニューバーは外付けより高く、
/// 帯を描くアプリが詰める量もそれに応じて変わる。
enum BarShape {
    /// 画面ごとの余白。ポイント。
    private(set) static var insets: [CGDirectDisplayID: CGFloat] = [:]

    private static var measuredAt: CFAbsoluteTime = 0
    private static let interval: CFAbsoluteTime = 15

    static var isStale: Bool { CFAbsoluteTimeGetCurrent() - measuredAt > interval }

    /// 手で入れた値があればそれを使う。無ければ測った値。
    static func effective(for display: CGDirectDisplayID) -> CGFloat {
        if let manual = UserDefaults.standard.object(forKey: "verticalInset") as? Double {
            return CGFloat(manual)
        }
        return insets[display] ?? 0
    }

    /// 画面ごとに、項目の並びに沿って何本か読み、中央値を採る。
    ///
    /// 項目と項目の間には隙間が無い。Ice は項目を詰めて並べるので、
    /// 空いた列を探しても見つからない。代わりに各項目の左端を読む。
    /// 絵が始まる前の余白にあたるので、たいていは帯の地の色が出る。
    /// それでも絵に当たることはあるため、何本か読んで中央値を採る。
    static func measure(items: [StatusItem]) {
        measuredAt = CFAbsoluteTimeGetCurrent()
        var measured: [CGDirectDisplayID: CGFloat] = [:]

        for screen in NSScreen.screens {
            let display = StatusItems.displayID(of: screen)
            let bounds = CGDisplayBounds(display)
            let onScreen = items.filter { bounds.intersects($0.frame) }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard let height = onScreen.first?.frame.height, height > 8 else { continue }

            let readings =
                onScreen
                .compactMap { read(column: $0.frame.minX + 1, top: bounds.minY, height: height) }
                .sorted()
            guard !readings.isEmpty else { continue }
            measured[display] = readings[readings.count / 2]
        }

        insets = measured
    }

    /// 一列読んで、上下それぞれ帯と違う色が続く分を数える。測れなければ nil。
    private static func read(column x: CGFloat, top: CGFloat, height: CGFloat) -> CGFloat? {
        let region = CGRect(x: x, y: top, width: 1, height: height)
        guard let image = Backdrop.captureScreen(region: region) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard bitmap.pixelsHigh > 4 else { return nil }

        let scale = CGFloat(bitmap.pixelsHigh) / height
        guard let middle = bitmap.colorAt(x: 0, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB)
        else { return nil }

        func differs(_ y: Int) -> Bool {
            guard let color = bitmap.colorAt(x: 0, y: y)?.usingColorSpace(.sRGB) else { return false }
            let distance =
                abs(color.redComponent - middle.redComponent)
                + abs(color.greenComponent - middle.greenComponent)
                + abs(color.blueComponent - middle.blueComponent)
            return distance > 0.12
        }

        var top = 0
        while top < bitmap.pixelsHigh / 2, differs(top) { top += 1 }
        var bottom = 0
        while bottom < bitmap.pixelsHigh / 2, differs(bitmap.pixelsHigh - 1 - bottom) { bottom += 1 }

        let inset = CGFloat(max(top, bottom)) / scale
        // 極端な値は測り損ねとみなす
        return inset < height / 3 ? inset.rounded() : 0
    }
}
