import AppKit

/// 絵を描くだけのビュー。枠に収まる最大の大きさで、縦横比を保つ。
final class FaceView: NSView {
    var image: NSImage

    init(frame: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) は使わない") }

    override func draw(_ dirtyRect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * fit, height: image.size.height * fit)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        image.draw(
            in: NSRect(origin: origin, size: size),
            from: .zero, operation: .sourceOver, fraction: 1)
    }
}

/// メニューバーと同じ層に置く、マウスを通す板。
private final class PassThroughPanel: NSPanel {
    init(frame: NSRect, level: NSWindow.Level) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        self.level = level
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        // NSPanel は既定でアプリが非アクティブになると隠れる。常駐アプリは
        // アクティブにならないので、切っておかないと一度も表示されない。
        hidesOnDeactivate = false
        collectionBehavior = [.fullScreenNone, .ignoresCycle, .canJoinAllSpaces, .stationary]
        appearance = NSApp.effectiveAppearance
    }
}

/// 項目ひとつを覆う板。
///
/// 背景と顔で二枚に分ける。顔は項目の幅より広く描けるようにしたいが、項目の矩形は
/// 隙間なく並んでいるので、はみ出した分は隣の項目に重なる。一枚にすると、隣の
/// 不透明な背景がこちらの顔を覆うか覆わないかが、板の作られた順で決まってしまう。
/// 顔をすべての背景より上の層に置けば、その順番に左右されない。
///
/// マウスはどちらも素通しさせる。本物はそのまま生きているので、クリックすれば
/// 本来のメニューが開く。
final class OverlayPanel {
    private let backdropPanel: PassThroughPanel
    private let facePanel: PassThroughPanel
    private let backdropView = NSImageView()
    private let faceView: FaceView

    /// 背景を撮った時の矩形。変わらないうちは撮り直さない。
    private var capturedRegion: CGRect = .null
    /// 撮った時刻。板が動かなくても背景のほうが変わることがある。
    /// 壁紙の変更や、メニューバーの透明度の切り替えがそれに当たる。
    private var capturedAt: CFAbsoluteTime = 0
    private let staleAfter: CFAbsoluteTime = 3

    init(item: StatusItem, image: NSImage, scale: CGFloat) {
        let backdrop = OverlayPanel.backdropFrame(for: item)
        let face = OverlayPanel.faceFrame(for: item, scale: scale)

        backdropPanel = PassThroughPanel(frame: backdrop, level: .statusBar)
        // 顔はすべての背景より上。同じ層に置くと、隣の背景に覆われることがある。
        facePanel = PassThroughPanel(
            frame: face,
            level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1))

        backdropView.frame = NSRect(origin: .zero, size: backdrop.size)
        backdropView.imageScaling = .scaleAxesIndependently
        backdropView.autoresizingMask = [.width, .height]
        let backdropContent = NSView(frame: NSRect(origin: .zero, size: backdrop.size))
        backdropContent.addSubview(backdropView)
        backdropPanel.contentView = backdropContent

        faceView = FaceView(frame: NSRect(origin: .zero, size: face.size), image: image)
        faceView.autoresizingMask = [.width, .height]
        let faceContent = NSView(frame: NSRect(origin: .zero, size: face.size))
        faceContent.addSubview(faceView)
        facePanel.contentView = faceContent

        backdropPanel.orderFrontRegardless()
        facePanel.orderFrontRegardless()
    }

    /// 背景を敷く矩形。上下に余白を取ると、その分だけ背景を敷かない。
    /// メニューバーの見た目を変えるアプリが帯の上下を詰めている場合、
    /// そこを透過のままにすると帯の形がつながる。
    private static func backdropFrame(for item: StatusItem) -> NSRect {
        let frame = StatusItems.toAppKit(item.frame)
        let inset = BarShape.effective(for: display(of: item.frame))
        return frame.insetBy(dx: 0, dy: min(inset, frame.height / 2 - 1))
    }

    /// 顔を描く矩形。
    ///
    /// 100% のときは背景と同じ。項目の幅より広げると隣に重なるので、
    /// 大きくすると言われたときだけ広げる。
    ///
    /// 広げるのは横だけ。縦に伸ばすとバーからはみ出して、机の上に顎が乗る。
    /// つまり帯の高さが頭打ちで、細い項目ほど設定が効き、元から高さいっぱいの
    /// 項目では何も起きない。
    private static func faceFrame(for item: StatusItem, scale: CGFloat) -> NSRect {
        let box = backdropFrame(for: item)
        guard scale > 1 else { return box }
        let side = min(min(box.width, box.height) * scale, box.height)
        let width = max(box.width, side)
        return NSRect(x: box.midX - width / 2, y: box.minY, width: width, height: box.height)
    }

    /// その矩形が乗っている画面。余白は画面ごとに違うので、板ごとに引く。
    private static func display(of frame: CGRect) -> CGDirectDisplayID {
        StatusItems.screen(containing: frame).map(StatusItems.displayID) ?? 0
    }

    func update(item: StatusItem, image: NSImage, scale: CGFloat) {
        let backdrop = OverlayPanel.backdropFrame(for: item)
        if backdropPanel.frame != backdrop {
            backdropPanel.setFrame(backdrop, display: false)
        }
        let face = OverlayPanel.faceFrame(for: item, scale: scale)
        if facePanel.frame != face {
            facePanel.setFrame(face, display: false)
        }
        if faceView.image !== image {
            faceView.image = image
            faceView.needsDisplay = true
        }
        refreshBackdrop(region: item.frame, windowID: item.windowID)
    }

    func orderOut(_ sender: Any?) {
        backdropPanel.orderOut(sender)
        facePanel.orderOut(sender)
    }

    /// 背景を敷き直す。画面をまたぐと壁紙が変わるので、位置が動いたら撮る。
    func refreshBackdrop(region: CGRect, windowID: CGWindowID, force: Bool = false) {
        let aged = CFAbsoluteTimeGetCurrent() - capturedAt > staleAfter
        guard force || region != capturedRegion || aged else { return }
        // 板を隠す必要はない。撮る対象は項目より下にあるものだけで、
        // 板は項目より前面にあるため写り込まない。隠すと一瞬だけ本物が見えてちらつく。
        let inset = BarShape.effective(for: OverlayPanel.display(of: region))
        let target = region.insetBy(dx: 0, dy: min(inset, region.height / 2 - 1))
        guard let captured = Backdrop.capture(region: target, below: windowID) else { return }
        backdropView.image = NSImage(cgImage: captured, size: backdropView.bounds.size)
        capturedRegion = region
        capturedAt = CFAbsoluteTimeGetCurrent()
    }
}
