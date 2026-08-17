import AppKit

/// 項目の一覧と、それぞれに当てる絵を選ぶ窓。
///
/// 上段はメニューバーと同じ横一列。下段はキャラクターの一覧を格子で並べる。
/// 項目を選んでからキャラクターを押す、という順で割り当てる。
/// 縦積みの一覧に較べて、上段がそのまま仕上がりの下見になる。
final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let itemStrip = NSStackView()
    private let charactersGrid = NSStackView()
    /// 上段の下。選んでいる項目の名前と案内
    private let itemHint = NSTextField(labelWithString: "")
    /// 下段の下。今の割り当てと、ホバー中のキャラクター名
    private let characterHint = NSTextField(labelWithString: "")

    private var onChange: (() -> Void)?
    private var items: [StatusItem] = []
    private var selectedKey: String?
    private var insetField: NSTextField?

    private let cellSide: CGFloat = 46
    /// 折り返す個数。上段と下段で列を揃える
    private let perRow = 8

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

        for label in [itemHint, characterHint] {
            label.textColor = .secondaryLabelColor
            label.font = .systemFont(ofSize: 11)
            // 長い名前で窓が横に伸びないようにする
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.truncatesLastVisibleLine = true
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.translatesAutoresizingMaskIntoConstraints = false
        }

        charactersGrid.orientation = .vertical
        charactersGrid.spacing = 4
        charactersGrid.alignment = .leading

        let sizeLabel = NSTextField(labelWithString: "大きさ")
        let size = NSPopUpButton()
        for value in [0.6, 0.8, 1.0, 1.2, 1.4] {
            size.addItem(withTitle: String(format: "%.0f%%", value * 100))
            size.lastItem?.representedObject = value
        }
        let stored = UserDefaults.standard.double(forKey: "faceScale")
        size.selectItem(withTitle: String(format: "%.0f%%", (stored > 0 ? stored : 1.0) * 100))
        size.target = self
        size.action = #selector(pickSize(_:))

        let insetLabel = NSTextField(labelWithString: "上下の余白")
        // 空欄なら自動。数値を入れたらそれで上書きする。
        let manual = UserDefaults.standard.object(forKey: "verticalInset") as? Double
        let inset = NSTextField(string: manual.map { String(Int($0)) } ?? "")
        inset.placeholderString = "自動"
        inset.alignment = .right
        inset.target = self
        inset.action = #selector(setInset(_:))
        inset.translatesAutoresizingMaskIntoConstraints = false
        inset.widthAnchor.constraint(equalToConstant: 44).isActive = true
        insetField = inset

        let openFolder = NSButton(title: "フォルダを開く", target: self, action: #selector(openCharactersFolder))
        let refresh = NSButton(title: "更新", target: self, action: #selector(reload))

        let footer = NSStackView(views: [sizeLabel, size, insetLabel, inset, openFolder, refresh])
        footer.orientation = .horizontal
        footer.spacing = 8

        let root = NSStackView(views: [
            sectionLabel("メニューバーの項目"), itemStrip, itemHint,
            sectionLabel("キャラクター"), charactersGrid, characterHint, footer,
        ])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.setCustomSpacing(16, after: itemHint)

        window.contentView = root
        reload()
    }

    /// 案内の行が窓幅を超えないようにする。
    private func constrainHints(to width: CGFloat) {
        for label in [itemHint, characterHint] {
            label.preferredMaxLayoutWidth = width
            if let existing = label.constraints.first(where: { $0.firstAttribute == .width }) {
                existing.constant = width
            } else {
                label.widthAnchor.constraint(equalToConstant: width).isActive = true
            }
        }
    }

    /// 窓の幅は升目から逆算する。中身の大きさに任せると、行が内側の余白を
    /// 上回ったときに右の余白が押し出される。
    private func fitWindow() {
        guard let window, let root = window.contentView else { return }
        let inset: CGFloat = 16
        let gap: CGFloat = 4
        let columns = CGFloat(perRow)
        let width = inset * 2 + columns * cellSide + (columns - 1) * gap
        constrainHints(to: width - inset * 2)
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
        // 名前を持たない項目も並べる。当てられはしないが、黙って消すとバーに
        // 見えている数と合わず、探しているものが無いのか壊れているのか分からない。
        let all = StatusItems.resolved().filter { !$0.key.isEmpty }
        var byDisplay: [CGDirectDisplayID: [StatusItem]] = [:]
        for item in all {
            guard let host = StatusItems.screen(containing: item.frame) else { continue }
            byDisplay[StatusItems.displayID(of: host), default: []].append(item)
        }
        var seen = Set<String>()
        items = (byDisplay.values.max(by: { $0.count < $1.count }) ?? [])
            .sorted { $0.frame.minX < $1.frame.minX }
            .filter { seen.insert($0.key).inserted }

        // 既定では選ばない。勝手に 1 個目を選ぶと、その項目の案内が出てしまう。
        if let key = selectedKey, !items.contains(where: { $0.key == key }) {
            selectedKey = nil
        }
        rebuildStrip()
        rebuildCharacters()
        updateHint()
        fitWindow()
    }

    private func rebuildStrip() {
        itemStrip.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var cells: [NSView] = []
        for item in items {
            let assigned = Assignments.image(for: item.key, aliases: item.aliases)
            let nameless = Self.isNameless(item.key)
            let cell = Cell(image: assigned ?? originalIcon(of: item),
                            side: cellSide,
                            selected: item.key == selectedKey,
                            dimmed: assigned == nil)
            let name = nameless ? Self.namelessHint : displayName(for: item.key)
            cell.toolTip = name
            cell.onHover = { [weak self] inside in
                self?.itemHint.stringValue = inside ? name : self?.itemHintText() ?? ""
            }
            // 名前を持たない項目は選べない。当てても次の起動では別の項目に付く。
            if !nameless {
                cell.onClick = { [weak self] in
                    self?.selectedKey = item.key
                    self?.rebuildStrip()
                    self?.rebuildCharacters()
                    self?.updateHint()
                }
            }
            cells.append(cell)
        }
        for row in rows(of: cells, perRow: perRow) {
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

    /// 名乗らない項目。`Item-0` は macOS が付ける仮の名前で、
    /// どのアプリのものかは分からない。画面が一つしか無いと借りる先も無い。
    static func isNameless(_ key: String) -> Bool {
        key.hasPrefix("Item-")
    }

    static let namelessHint = "名前を名乗らない項目。どのアプリのものか判別できないので当てられません"

    /// いま選んでいる項目。別の画面での鍵も要るので、鍵だけでなく項目ごと持つ。
    private var selectedItem: StatusItem? {
        items.first { $0.key == selectedKey }
    }

    private func rebuildCharacters() {
        charactersGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let current = selectedItem.flatMap {
            Assignments.character(for: $0.key, aliases: $0.aliases)
        }
        // 項目を選ぶまでは当てる先が無い。薄くして、押しても何も起きないようにする。
        charactersGrid.alphaValue = selectedKey == nil ? 0.35 : 1

        // 項目を選ぶまでは、どの升目にも枠を付けない
        let hasTarget = selectedKey != nil
        var cells: [NSView] = []
        let none = Cell(image: nil, side: cellSide, selected: hasTarget && current == nil, dimmed: false)
        none.label = "なし"
        none.toolTip = "なし"
        none.onHover = { [weak self] inside in
            self?.characterHint.stringValue = inside ? "なし" : self?.characterHintText() ?? ""
        }
        none.onClick = { [weak self] in self?.assign(nil) }
        cells.append(none)

        for character in Assignments.availableCharacters() {
            let image = NSImage(contentsOf: Assignments.charactersDirectory
                .appendingPathComponent("\(character).png"))
            let cell = Cell(image: image, side: cellSide,
                            selected: hasTarget && current == character, dimmed: false)
            let name = Assignments.displayName(for: character)
            cell.toolTip = name
            cell.onHover = { [weak self] inside in
                self?.characterHint.stringValue = inside ? name : self?.characterHintText() ?? ""
            }
            cell.onClick = { [weak self] in self?.assign(character) }
            cells.append(cell)
        }

        for row in rows(of: cells, perRow: perRow) {
            charactersGrid.addArrangedSubview(row)
        }
    }

    private func itemHintText() -> String {
        if items.isEmpty {
            return "項目が見つかりません。画面収録の許可を確認してください。"
        }
        guard let key = selectedKey else {
            return "キャラクターを当てる項目を選んでください"
        }
        return "\(displayName(for: key)) に当てるキャラクターを選んでください"
    }

    private func characterHintText() -> String {
        guard let item = selectedItem else { return " " }
        return Assignments.character(for: item.key, aliases: item.aliases)
            .map { "いまは \(Assignments.displayName(for: $0))" } ?? "いまは なし"
    }

    private func updateHint() {
        itemHint.stringValue = itemHintText()
        characterHint.stringValue = characterHintText()
    }

    private func assign(_ character: String?) {
        // 当てる先が無いうちは何もしない。見た目でも薄くしてある。
        guard let item = selectedItem else { return }
        Assignments.set(character: character, for: item.key, aliases: item.aliases)
        onChange?()
        rebuildStrip()
        rebuildCharacters()
        updateHint()
    }

    // MARK: - 名前と絵

    /// macOS 自身の項目。名前も記号も `NSWorkspace` からは引けないので、
    /// 読み替えと SF Symbols を持っておく。
    private static let systemItems: [String: (name: String, symbol: String)] = [
        "Clock": ("時計", "clock"),
        "Battery": ("バッテリー", "battery.100"),
        "Sound": ("音量", "speaker.wave.2"),
        "BentoBox-0": ("コントロールセンター", "switch.2"),
        "UserSwitcher": ("ユーザ", "person.crop.circle"),
        "Display": ("ディスプレイ", "display"),
        "Siri": ("Siri", "mic"),
        "WiFi": ("Wi-Fi", "wifi"),
        "AudioVideoModule": ("音声と映像", "video"),
        "TimeMachine": ("Time Machine", "clock.arrow.circlepath"),
        "KeyboardBrightness": ("キーボードの明るさ", "keyboard"),
        "TextInput": ("入力ソース", "character.textbox"),
        "ScreenMirroring": ("画面ミラーリング", "rectangle.on.rectangle"),
        "NowPlaying": ("再生中", "play.circle"),
        "FocusModes": ("集中モード", "moon"),
        "Bluetooth": ("Bluetooth", "wave.3.right"),
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
            // 途中に含まれるだけの一致は取り違えが多い。頭から一致した場合だけ採る。
            // `ItsycalStatusItem` は当たり、`rocket_status_item` はどれにも当たらない。
            guard candidate.count >= 4, needle.hasPrefix(candidate) else { continue }
            if best == nil || candidate.count > best!.length { best = (name, candidate.count) }
        }
        return best?.name
    }

    /// 鍵は `io.kkweb.konechi#0` のような形。人に見せる形へ直す。
    private func displayName(for key: String) -> String {
        let parts = key.components(separatedBy: "#")
        let base = parts.first ?? key
        let number = Int(parts.count > 1 ? parts[1] : "0") ?? 0

        var name = Self.systemItems[base]?.name ?? appName(forBundleID: base)
            ?? runningAppName(matching: base)
            ?? base.components(separatedBy: ".").last ?? base
        // `Doll_com.hnc.Discord` のように、何のための項目かが入っている場合
        if base.contains("_"), let owner = base.components(separatedBy: "_").first {
            let target = base.components(separatedBy: "_").dropFirst().joined(separator: "_")
            name = "\(owner)（\(target.components(separatedBy: ".").last ?? target)）"
        }
        let shown = name.count > 24 ? name.prefix(24) + "…" : name[...]
        return number == 0 ? String(shown) : "\(shown) の \(number + 1) 個目"
    }

    /// 未割り当ての項目に何を出すか。
    ///
    /// メニューバーの見た目を撮る手も試したが、板が乗っている状態では
    /// 安定して撮れなかった。アプリのアイコンを使う。
    /// どのアプリか分からない項目は、記号で代用する。
    private func originalIcon(of item: StatusItem) -> NSImage? {
        let base = item.key.components(separatedBy: "#").first ?? item.key
        if let symbol = Self.systemItems[base]?.symbol,
           let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            return image
        }
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

    /// メニューバーの見た目を変えるアプリと併用するときに使う。
    /// 上下に余白を取ると、そこには背景を敷かないので、帯の形がつながる。
    @objc private func setInset(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            UserDefaults.standard.removeObject(forKey: "verticalInset")
        } else {
            let value = max(0, min(Double(text) ?? 0, 8))
            sender.stringValue = String(Int(value))
            UserDefaults.standard.set(value, forKey: "verticalInset")
        }
        onChange?()
    }

    @objc private func openCharactersFolder() {
        Assignments.prepareDirectories()
        NSWorkspace.shared.open(Assignments.charactersDirectory)
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

/// 項目やキャラクターを一つ表すます。選択中は枠が付く。
private final class Cell: NSView {
    var onClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
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
            // 何も無いと他の升目と釣り合わないので、斜線を敷く
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}
