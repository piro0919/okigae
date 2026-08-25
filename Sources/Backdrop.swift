import AppKit

/// 項目の背後に実際に描かれているものを撮る。
///
/// メニューバーは透明が既定で、その場合は壁紙が透ける。「透明度を下げる」を
/// 有効にしていれば単色になる。背後を撮ってそのまま敷けば、どちらでも一致するので
/// 設定を読む必要がない。
enum Backdrop {
    /// `CGWindowListCreateImage` は macOS 15 でコンパイルできなくなったが、実体は残っている。
    /// ScreenCaptureKit にはメニューバー周りを同じように撮る手段が無いため、
    /// C の関数として引いて呼ぶ。将来消される可能性がある箇所。
    private typealias CreateImage = @convention(c) (CGRect, UInt32, CGWindowID, UInt32) -> Unmanaged<CGImage>?

    private static let createImage: CreateImage? = {
        guard let handle = dlopen(nil, RTLD_NOW),
            let symbol = dlsym(handle, "CGWindowListCreateImage")
        else { return nil }
        return unsafeBitCast(symbol, to: CreateImage.self)
    }()

    /// 撮影そのものができるか。画面収録の権限が無い場合はここでは分からず、
    /// `capture` が空の画像を返すことで表面化する。
    static var isAvailable: Bool { createImage != nil }

    /// 画面に出ているものをそのまま撮る。板の形を測るために使う。
    static func captureScreen(region: CGRect) -> CGImage? {
        guard let createImage else { return nil }
        let listOption = CGWindowListOption.optionOnScreenOnly.rawValue
        let imageOption = CGWindowImageOption([.bestResolution, .boundsIgnoreFraming]).rawValue
        return createImage(region, listOption, kCGNullWindowID, imageOption)?.takeRetainedValue()
    }

    /// - Parameters:
    ///   - region: CoreGraphics 座標の矩形。
    ///   - windowID: この項目より下にあるものだけを撮る。
    static func capture(region: CGRect, below windowID: CGWindowID) -> CGImage? {
        capture(
            region: region, windowID: windowID,
            listOption: CGWindowListOption.optionOnScreenBelowWindow.rawValue)
    }

    /// その項目そのものを撮る。設定画面で、本来のアイコンを見せるために使う。
    static func capture(region: CGRect, of windowID: CGWindowID) -> CGImage? {
        capture(
            region: region, windowID: windowID,
            listOption: CGWindowListOption.optionIncludingWindow.rawValue)
    }

    private static func capture(region: CGRect, windowID: CGWindowID, listOption: UInt32) -> CGImage? {
        guard let createImage else { return nil }
        let imageOption = CGWindowImageOption([.bestResolution, .boundsIgnoreFraming]).rawValue
        return createImage(region, listOption, windowID, imageOption)?.takeRetainedValue()
    }

    // 明示した窓だけを合成して撮る。こちらも macOS 15 でコンパイルできない。
    private typealias CreateImageFromArray = @convention(c) (CGRect, CFArray, UInt32) -> Unmanaged<CGImage>?

    private static let createImageFromArray: CreateImageFromArray? = {
        guard let handle = dlopen(nil, RTLD_NOW),
            let symbol = dlsym(handle, "CGWindowListCreateImageFromArray")
        else { return nil }
        return unsafeBitCast(symbol, to: CreateImageFromArray.self)
    }()

}
