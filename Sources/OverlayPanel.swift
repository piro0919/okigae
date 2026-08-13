import AppKit

/// 絵を描くだけのビュー。枠に収まる最大の大きさで、縦横比を保つ。
final class FaceView: NSView {
    var image: NSImage
    var scale: CGFloat

    init(frame: NSRect, image: NSImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) は使わない") }

    override func draw(_ dirtyRect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        // 板の幅は項目ぴったりなので、はみ出すと切れる。収まる大きさに合わせる。
        let fit = min(bounds.width / image.size.width, bounds.height / image.size.height) * scale
        let size = NSSize(width: image.size.width * fit, height: image.size.height * fit)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        image.draw(in: NSRect(origin: origin, size: size),
                   from: .zero, operation: .sourceOver, fraction: 1)
    }
}

/// 項目ひとつを覆う板。
///
/// メニューバーと同じ層に置き、マウスは素通しさせる。本物はそのまま生きているので、
/// クリックすれば本来のメニューが開く。
final class OverlayPanel: NSPanel {
    private let backdropView = NSImageView()
    private let faceView: FaceView
    /// 背景を撮った時の矩形。変わらないうちは撮り直さない。
    private var capturedRegion: CGRect = .null
    /// 撮った時刻。板が動かなくても背景のほうが変わることがある。
    /// 壁紙の変更や、メニューバーの透明度の切り替えがそれに当たる。
    private var capturedAt: CFAbsoluteTime = 0
    private let staleAfter: CFAbsoluteTime = 3

    init(item: StatusItem, image: NSImage, scale: CGFloat) {
        let frame = StatusItems.toAppKit(item.frame)
        faceView = FaceView(frame: NSRect(origin: .zero, size: frame.size), image: image, scale: scale)

        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        // NSPanel は既定でアプリが非アクティブになると隠れる。常駐アプリは
        // アクティブにならないので、切っておかないと一度も表示されない。
        hidesOnDeactivate = false
        collectionBehavior = [.fullScreenNone, .ignoresCycle, .canJoinAllSpaces, .stationary]
        appearance = NSApp.effectiveAppearance

        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        backdropView.frame = content.bounds
        backdropView.imageScaling = .scaleAxesIndependently
        backdropView.autoresizingMask = [.width, .height]
        content.addSubview(backdropView)

        faceView.autoresizingMask = [.width, .height]
        content.addSubview(faceView)

        contentView = content
        orderFrontRegardless()
    }

    func update(item: StatusItem, image: NSImage, scale: CGFloat) {
        let frame = StatusItems.toAppKit(item.frame)
        if self.frame != frame {
            setFrame(frame, display: false)
        }
        if faceView.image !== image || faceView.scale != scale {
            faceView.image = image
            faceView.scale = scale
            faceView.needsDisplay = true
        }
        refreshBackdrop(region: item.frame, windowID: item.windowID)
    }

    /// 背景を敷き直す。画面をまたぐと壁紙が変わるので、位置が動いたら撮る。
    func refreshBackdrop(region: CGRect, windowID: CGWindowID, force: Bool = false) {
        let aged = CFAbsoluteTimeGetCurrent() - capturedAt > staleAfter
        guard force || region != capturedRegion || aged else { return }
        // 板を隠す必要はない。撮る対象は項目より下にあるものだけで、
        // 板は項目より前面にあるため写り込まない。隠すと一瞬だけ本物が見えてちらつく。
        guard let captured = Backdrop.capture(region: region, below: windowID) else { return }
        backdropView.image = NSImage(cgImage: captured, size: backdropView.bounds.size)
        capturedRegion = region
        capturedAt = CFAbsoluteTimeGetCurrent()
    }
}
