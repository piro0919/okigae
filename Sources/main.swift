import AppKit

@main
enum Okigae {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 項目ひとつにつき板ひとつ。
    ///
    /// 鍵にウィンドウ ID は使えない。同じ項目に対して複数のウィンドウが存在し、
    /// 画面に出るほうが数秒ごとに入れ替わるアプリがある。ID で対応付けると
    /// 入れ替わりのたびに板を作り直すことになり、その隙間が見えてちらつく。
    private var panels: [String: OverlayPanel] = [:]

    /// 画面と項目の組をひとつの鍵にする。
    private func panelKey(for item: StatusItem) -> String {
        let display = StatusItems.screen(containing: item.frame).map { StatusItems.displayID(of: $0) } ?? 0
        return "\(display)|\(item.key)"
    }
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var didRequestPermission = false
    private var settingsWindow: SettingsWindow?

    /// 絵の大きさ。枠に収まる大きさを 1.0 とした倍率。設定画面から変える。
    fileprivate var faceScale: CGFloat {
        let stored = UserDefaults.standard.double(forKey: "faceScale")
        return stored > 0 ? CGFloat(stored) : 1.0
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Assignments.load()
        installStatusItem()

        // 更新の確認は起動時に1回だけ。見つかったときだけ画面が出る
        Updater.shared.checkQuietly()

        sync()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.sync()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        panels.values.forEach { $0.orderOut(nil) }
    }

    // MARK: - 権限

    /// 画面収録の権限を確かめる。
    ///
    /// 背景の撮影だけでなく、項目の識別にも要る。権限が無いとウィンドウタイトルが
    /// 空で返り、どの項目がどのアプリのものか分からなくなる。
    /// 許可は取り消されることもあるので、待つだけで終了はしない。
    private func hasPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        if !didRequestPermission {
            didRequestPermission = true
            // 初回はこれで許可を求める画面が出る。許可した後はアプリの開き直しが要る。
            CGRequestScreenCaptureAccess()
        }
        return false
    }

    @objc private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 自分のメニュー

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "menu-icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            // テンプレート画像にすると、明暗どちらのメニューバーでも macOS が色を合わせる。
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            item.button?.image = image
        } else {
            // 絵が見つからないときの保険。通常は起きない
            item.button?.title = "Okigae"
        }
        item.menu = NSMenu()
        item.menu?.delegate = self
        statusItem = item
    }

    @objc private func assign(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let face = sender.title == "なし" ? nil : sender.title
        Assignments.set(face: face, for: key)
        rebuildAll()
    }


    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow { [weak self] in self?.rebuildAll() }
        }
        settingsWindow?.show()
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkNow()
    }



    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 板の同期

    private func rebuildAll() {
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        sync()
    }

    private func sync() {
        // 権限が無いときは何も置かない。メニューに「画面収録を許可…」が出る
        guard hasPermission() else { return }
        let items = StatusItems.resolved().filter { !$0.key.isEmpty }
        var alive = Set<String>()

        for item in items {
            let key = panelKey(for: item)
            guard let image = Assignments.image(for: item.key) else { continue }
            alive.insert(key)
            if let panel = panels[key] {
                panel.update(item: item, image: image, scale: faceScale)
            } else {
                let panel = OverlayPanel(item: item, image: image, scale: faceScale)
                panel.refreshBackdrop(region: item.frame, windowID: item.windowID, force: true)
                panels[key] = panel
            }
        }

        // 消えた項目と、割り当てを外された項目の板を片付ける。
        for (key, panel) in panels where !alive.contains(key) {
            panel.orderOut(nil)
            panels[key] = nil
        }
    }
}

// MARK: - メニューの中身

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 文言は macOS と Sparkle の言い回しに合わせる。
        // 更新の画面は Sparkle が出すので、そちらの「アップデート」に揃える。
        menu.addItem(withTitle: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "アップデートを確認…", action: #selector(checkForUpdates), keyEquivalent: "")

        if !CGPreflightScreenCaptureAccess() {
            menu.addItem(.separator())
            menu.addItem(withTitle: "画面収録を許可…", action: #selector(openPrivacySettings), keyEquivalent: "")
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Okigae を終了", action: #selector(quit), keyEquivalent: "q")

        for entry in menu.items where entry.action != nil {
            entry.target = self
        }
    }
}
