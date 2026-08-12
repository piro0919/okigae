import AppKit

/// 項目の一覧と、それぞれに当てる絵を選ぶ窓。
///
/// メニューの入れ子でも同じことはできるが、鍵の文字列だけでは
/// どの行がどのアプリか分かりにくい。本物のアイコンを並べて見せる。
final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let stack = NSStackView()
    private var onChange: (() -> Void)?

    convenience init(onChange: @escaping () -> Void) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Okigae"
        window.center()
        // 全画面のアプリが手前にあると、常駐アプリの窓は元の Space に開いてしまう。
        // 呼ばれた場所に出す。
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.init(window: window)
        window.delegate = self
        self.onChange = onChange
        build()
    }

    private func build() {
        guard let window else { return }

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = stack
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let sizeLabel = NSTextField(labelWithString: "絵の大きさ")
        let size = NSPopUpButton()
        for value in [0.6, 0.8, 1.0, 1.2, 1.4] {
            size.addItem(withTitle: String(format: "%.0f%%", value * 100))
            size.lastItem?.representedObject = value
        }
        let current = UserDefaults.standard.double(forKey: "faceScale")
        size.selectItem(withTitle: String(format: "%.0f%%", (current > 0 ? current : 1.0) * 100))
        size.target = self
        size.action = #selector(pickSize(_:))

        let openFolder = NSButton(title: "絵のフォルダを開く", target: self, action: #selector(openFacesFolder))
        let refresh = NSButton(title: "一覧を更新", target: self, action: #selector(reload))
        let footer = NSStackView(views: [sizeLabel, size, openFolder, refresh])
        footer.orientation = .horizontal
        footer.spacing = 8
        footer.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scroll)
        content.addSubview(footer)
        window.contentView = content

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalTo: scroll.widthAnchor).isActive = true

        reload()
    }

    @objc private func reload() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let faces = Assignments.availableFaces()
        var seen = Set<String>()
        let items = StatusItems.resolved()
            .filter { !$0.key.isEmpty }
            .sorted { $0.frame.minX < $1.frame.minX }
            .filter { seen.insert($0.key).inserted }

        if items.isEmpty {
            let empty = NSTextField(labelWithString: "項目が見つかりません。画面収録の許可を確認してください。")
            stack.addArrangedSubview(empty)
            return
        }

        for item in items {
            stack.addArrangedSubview(row(for: item, faces: faces))
        }
    }

    private func row(for item: StatusItem, faces: [String]) -> NSView {
        let preview = NSImageView()
        preview.image = originalIcon(of: item)
        preview.imageScaling = .scaleProportionallyDown
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.widthAnchor.constraint(equalToConstant: 22).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let label = NSTextField(labelWithString: displayName(for: item.key))
        label.lineBreakMode = .byTruncatingMiddle
        label.toolTip = item.key
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 200).isActive = true

        let picker = NSPopUpButton()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.widthAnchor.constraint(equalToConstant: 130).isActive = true
        picker.addItem(withTitle: "なし")
        for face in faces {
            picker.addItem(withTitle: face)
            if let image = NSImage(contentsOf: Assignments.facesDirectory
                .appendingPathComponent("\(face).png")) {
                image.size = NSSize(width: 16, height: 16)
                picker.lastItem?.image = image
            }
        }
        // 絵が消えている割り当てが残っていると、選択欄が空欄になる。「なし」に寄せる。
        let current = Assignments.table[item.key]
        picker.selectItem(withTitle: faces.contains(current ?? "") ? (current ?? "なし") : "なし")
        picker.target = self
        picker.action = #selector(pick(_:))
        picker.identifier = NSUserInterfaceItemIdentifier(item.key)

        let row = NSStackView(views: [preview, label, picker])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    /// 鍵は `io.kkweb.konechi#0` のような形なので、末尾だけを見せる。
    private func displayName(for key: String) -> String {
        let base = key.hasSuffix("#0") ? String(key.dropLast(2)) : key
        return base.components(separatedBy: ".").last ?? base
    }

    /// その項目が本来出しているアイコンを撮る。どの行が何かを見分けるため。
    private func originalIcon(of item: StatusItem) -> NSImage? {
        guard let captured = Backdrop.capture(region: item.frame, of: item.windowID) else { return nil }
        return NSImage(cgImage: captured, size: NSSize(width: item.frame.width, height: item.frame.height))
    }

    @objc private func pick(_ sender: NSPopUpButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let face = sender.titleOfSelectedItem
        Assignments.set(face: face == "なし" ? nil : face, for: key)
        onChange?()
    }

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
