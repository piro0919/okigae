import AppKit

/// 項目の一覧と、それぞれに当てる絵を選ぶ窓。
///
/// 上段はメニューバーと同じ横一列。下段は絵の一覧を格子で並べる。
/// 項目を選んでから絵を押す、という順で割り当てる。
/// 縦積みの一覧に較べて、上段がそのまま仕上がりの下見になる。
final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let itemStrip = NSStackView()
    private let facesGrid = NSStackView()
    private let hint = NSTextField(labelWithString: "")

    private var onChange: (() -> Void)?
    private var items: [StatusItem] = []
    private var selectedKey: String?

    private let cellSide: CGFloat = 46
    private let facesPerRow = 6
    private let itemsPerRow = 8

    convenience init(onChange: @escaping () -> Void) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Okigae 設定"
        window.center()
        // 全画面のアプリが手前にあると、常駐アプリの窓は元の Space に開いてしまう。
        // 呼ばれた場所に出す。
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.init(window: window)
        window.delegate = self
        self.onChange = onChange
        build()
    }

    // MARK: - 組み立て

    private func build() {
        guard let window else { return }

        itemStrip.orientation = .vertical
        itemStrip.spacing = 4
        itemStrip.alignment = .leading

        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)

        facesGrid.orientation = .vertical
        facesGrid.spacing = 4
        facesGrid.alignment = .leading

        let sizeLabel = NSTextField(labelWithString: "絵の大きさ")
        let size = NSPopUpButton()
        for value in [0.6, 0.8, 1.0, 1.2, 1.4] {
            size.addItem(withTitle: String(format: "%.0f%%", value * 100))
            size.lastItem?.representedObject = value
        }
        let stored = UserDefaults.standard.double(forKey: "faceScale")
        size.selectItem(withTitle: String(format: "%.0f%%", (stored > 0 ? stored : 1.0) * 100))
        size.target = self
        size.action = #selector(pickSize(_:))

        let openFolder = NSButton(title: "絵のフォルダを開く", target: self, action: #selector(openFacesFolder))
        let refresh = NSButton(title: "更新", target: self, action: #selector(reload))

        let footer = NSStackView(views: [sizeLabel, size, openFolder, refresh])
        footer.orientation = .horizontal
        footer.spacing = 8

        let root = NSStackView(views: [
            sectionLabel("メニューバーの項目"), itemStrip, hint,
            sectionLabel("絵"), facesGrid, footer,
        ])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.setCustomSpacing(16, after: hint)

        window.contentView = root
        reload()
    }

    /// 窓の幅は升目から逆算する。中身の大きさに任せると、行が内側の余白を
    /// 上回ったときに右の余白が押し出される。
    private func fitWindow() {
        guard let window, let root = window.contentView else { return }
        let inset: CGFloat = 16
        let gap: CGFloat = 4
        let widest = CGFloat(max(itemsPerRow, facesPerRow))
        let width = inset * 2 + widest * cellSide + (widest - 1) * gap
        window.setContentSize(NSSize(width: width, height: root.fittingSize.height))
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - 中身

    @objc private func reload() {
        // 二つの画面の項目が混ざると並び順が壊れる。項目数が最も多い画面を基準にする。
        let all = StatusItems.resolved().filter { !$0.key.isEmpty && !$0.key.hasPrefix("Item-") }
        var byDisplay: [CGDirectDisplayID: [StatusItem]] = [:]
        for item in all {
            guard let host = StatusItems.screen(containing: item.frame) else { continue }
            byDisplay[StatusItems.displayID(of: host), default: []].append(item)
        }
        var seen = Set<String>()
        items = (byDisplay.values.max(by: { $0.count < $1.count }) ?? [])
            .sorted { $0.frame.minX < $1.frame.minX }
            .filter { seen.insert($0.key).inserted }

        if selectedKey == nil || !items.contains(where: { $0.key == selectedKey }) {
            selectedKey = items.first?.key
        }
        rebuildStrip()
        rebuildFaces()
        updateHint()
        fitWindow()
    }

    private func rebuildStrip() {
        itemStrip.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var cells: [NSView] = []
        for item in items {
            let assigned = Assignments.image(for: item.key)
            let cell = Cell(image: assigned ?? originalIcon(of: item),
                            side: cellSide,
                            selected: item.key == selectedKey,
                            dimmed: assigned == nil)
            cell.toolTip = displayName(for: item.key)
            cell.onClick = { [weak self] in
                self?.selectedKey = item.key
                self?.rebuildStrip()
                self?.rebuildFaces()
                self?.updateHint()
            }
            cells.append(cell)
        }
        for row in rows(of: cells, perRow: itemsPerRow) {
            itemStrip.addArrangedSubview(row)
        }
    }

    /// 折り返して行にまとめる。
    private func rows(of cells: [NSView], perRow: Int) -> [NSStackView] {
        stride(from: 0, to: cells.count, by: perRow).map { start in
            let row = NSStackView(views: Array(cells[start..<min(start + perRow, cells.count)]))
            row.orientation = .horizontal
            row.spacing = 4
            return row
        }
    }

    private func rebuildFaces() {
        facesGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let current = selectedKey.flatMap { Assignments.table[$0] }

        var cells: [NSView] = []
        let none = Cell(image: nil, side: cellSide, selected: current == nil, dimmed: false)
        none.label = "なし"
        none.onClick = { [weak self] in self?.assign(nil) }
        cells.append(none)

        for face in Assignments.availableFaces() {
            let image = NSImage(contentsOf: Assignments.facesDirectory.appendingPathComponent("\(face).png"))
            let cell = Cell(image: image, side: cellSide, selected: current == face, dimmed: false)
            cell.toolTip = face
            cell.onClick = { [weak self] in self?.assign(face) }
            cells.append(cell)
        }

        for row in rows(of: cells, perRow: facesPerRow) {
            facesGrid.addArrangedSubview(row)
        }
    }

    private func updateHint() {
        guard let key = selectedKey else {
            hint.stringValue = "項目が見つかりません。画面収録の許可を確認してください。"
            return
        }
        hint.stringValue = "\(displayName(for: key)) に当てる絵を選んでください"
    }

    private func assign(_ face: String?) {
        guard let key = selectedKey else { return }
        Assignments.set(face: face, for: key)
        onChange?()
        rebuildStrip()
        rebuildFaces()
    }

    // MARK: - 名前と絵

    /// macOS 内部の名前は、そのままでは何のことか分からない。
    private static let knownNames = [
        "Clock": "時計",
        "Battery": "バッテリー",
        "Sound": "音量",
        "BentoBox-0": "コントロールセンター",
        "UserSwitcher": "ユーザ",
        "Display": "ディスプレイ",
        "Siri": "Siri",
        "WiFi": "Wi-Fi",
    ]

    /// バンドル ID から実際のアプリ名を引く。`com.raycast.macos` を `macos` と
    /// 見せても伝わらない。
    private func appName(forBundleID id: String) -> String? {
        guard id.contains("."),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        else { return nil }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    /// バンドル ID を持たない名前を、動いているアプリと突き合わせる。
    ///
    /// 項目のタイトルは `raycastIcon` や `ItsycalStatusItem` のように、
    /// アプリ名を含んでいることが多い。字だけを取り出して照合する。
    private func runningAppName(matching title: String) -> String? {
        let needle = title.lowercased().filter { $0.isLetter }
        guard needle.count >= 4 else { return nil }

        var best: (name: String, length: Int)?
        for app in NSWorkspace.shared.runningApplications {
            guard let name = app.localizedName else { continue }
            let candidate = name.lowercased().filter { $0.isLetter }
            // 短い名前は他の語に埋もれる。`Doll` が `Dollar` に当たるような取り違えを避ける
            guard candidate.count >= 4, needle.contains(candidate) else { continue }
            // 複数当たったら、より長く一致したほうを採る
            if best == nil || candidate.count > best!.length { best = (name, candidate.count) }
        }
        return best?.name
    }

    /// 鍵は `io.kkweb.konechi#0` のような形。人に見せる形へ直す。
    private func displayName(for key: String) -> String {
        let parts = key.components(separatedBy: "#")
        let base = parts.first ?? key
        let number = Int(parts.count > 1 ? parts[1] : "0") ?? 0

        var name = Self.knownNames[base] ?? appName(forBundleID: base)
            ?? runningAppName(matching: base)
            ?? base.components(separatedBy: ".").last ?? base
        // `Doll_com.hnc.Discord` のように、何のための項目かが入っている場合
        if base.contains("_"), let owner = base.components(separatedBy: "_").first {
            let target = base.components(separatedBy: "_").dropFirst().joined(separator: "_")
            name = "\(owner)（\(target.components(separatedBy: ".").last ?? target)）"
        }
        return number == 0 ? name : "\(name) の \(number + 1) 個目"
    }

    /// 未割り当ての項目に何を出すか。
    ///
    /// メニューバーの見た目を撮る手も試したが、板が乗っている状態では
    /// 安定して撮れなかった。アプリのアイコンを使う。
    /// どのアプリか分からない項目は、記号で代用する。
    private func originalIcon(of item: StatusItem) -> NSImage? {
        let base = item.key.components(separatedBy: "#").first ?? item.key
        if base.contains("."),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: base) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // `Doll_com.hnc.Discord` のように、対象のバンドル ID が入っている場合
        if let tail = base.components(separatedBy: "_").dropFirst().first,
           tail.contains("."),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: tail) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let name = runningAppName(matching: base),
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }),
           let url = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)
    }

    // MARK: - 操作

    @objc private func pickSize(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Double else { return }
        UserDefaults.standard.set(value, forKey: "faceScale")
        onChange?()
    }

    @objc private func openFacesFolder() {
        Assignments.prepareDirectories()
        NSWorkspace.shared.open(Assignments.facesDirectory)
    }

    /// 常駐アプリは `.accessory` で動いていて、そのままでは窓が前面を取れない。
    /// 開いている間だけ通常のアプリとして振る舞わせ、閉じたら戻す。
    func show() {
        NSApp.setActivationPolicy(.regular)
        reload()
        showWindow(nil)
        window?.orderFrontRegardless()
        // 切り替えた直後の前面化は間に合わない。一拍置いてから要求する。
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.window?.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - 升目ひとつ

/// 項目や絵を一つ表すます。選択中は枠が付く。
private final class Cell: NSView {
    var onClick: (() -> Void)?
    var label: String? { didSet { needsDisplay = true } }

    private let image: NSImage?
    private let selected: Bool
    private let dimmed: Bool

    init(image: NSImage?, side: CGFloat, selected: Bool, dimmed: Bool) {
        self.image = image
        self.selected = selected
        self.dimmed = dimmed
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: side).isActive = true
        heightAnchor.constraint(equalToConstant: side).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) は使わない") }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        if selected {
            NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
            box.fill()
            NSColor.controlAccentColor.setStroke()
            box.lineWidth = 2
            box.stroke()
        } else {
            NSColor.quaternaryLabelColor.withAlphaComponent(0.35).setFill()
            box.fill()
        }

        if let image {
            let inset = bounds.insetBy(dx: 5, dy: 5)
            let fit = min(inset.width / image.size.width, inset.height / image.size.height)
            let size = NSSize(width: image.size.width * fit, height: image.size.height * fit)
            image.draw(in: NSRect(x: bounds.midX - size.width / 2,
                                  y: bounds.midY - size.height / 2,
                                  width: size.width, height: size.height),
                       from: .zero, operation: .sourceOver, fraction: dimmed ? 0.45 : 1)
        } else if let label {
            // 絵が無いと他の升目と釣り合わないので、斜線を敷く
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: bounds.minX + 10, y: bounds.minY + 10))
            slash.line(to: NSPoint(x: bounds.maxX - 10, y: bounds.maxY - 10))
            NSColor.quaternaryLabelColor.setStroke()
            slash.lineWidth = 2
            slash.stroke()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let text = label as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                      withAttributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
