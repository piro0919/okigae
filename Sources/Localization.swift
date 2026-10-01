import Foundation

// 表示文字列。
//
// Konechi・Gocci と同じく .lproj は使わず Swift の表に置く。ビルドを自前の shell で
// 組んでいるので、文字列だけのために資源の仕組みを足すと build.sh が重くなる。
// 言語は2つしかない。設定画面に言語の切り替えは置かず、システムに従う。

enum Language: String {
    case ja, en

    /// 実際に使う言語。既定は英語で、環境が日本語のときだけ日本語にする
    static var resolved: Language {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ja") ? .ja : .en
    }
}

@MainActor
enum L {
    static func t(_ ja: String, _ en: String) -> String {
        Language.resolved == .ja ? ja : en
    }

    // メニュー。文言は macOS と Sparkle の言い回しに合わせる
    static var settings: String { t("設定…", "Settings…") }
    static var checkForUpdates: String { t("アップデートを確認…", "Check for Updates…") }
    static var allowScreenRecording: String { t("画面収録を許可…", "Allow Screen Recording…") }
    static var quit: String { t("Okigae を終了", "Quit Okigae") }

    // 設定画面
    static var settingsTitle: String { t("Okigae 設定", "Okigae Settings") }
    static var size: String { t("大きさ", "Size") }
    static var verticalInset: String { t("上下の余白", "Vertical inset") }
    static var automatic: String { t("自動", "Auto") }
    static var openFolder: String { t("フォルダを開く", "Open Folder") }
    static var refresh: String { t("更新", "Refresh") }
    static var menuBarItems: String { t("メニューバーの項目", "Menu bar items") }
    static var characters: String { t("キャラクター", "Characters") }
    static var none: String { t("なし", "None") }
    static var namelessHint: String {
        t(
            "名前を名乗らない項目。どのアプリのものか判別できないので当てられません",
            "This item does not name itself, so there is no telling which app it belongs to. It cannot be assigned")
    }
    static var noItemsFound: String {
        t(
            "項目が見つかりません。画面収録の許可を確認してください。",
            "No items found. Check the Screen Recording permission.")
    }
    static var pickItem: String { t("キャラクターを当てる項目を選んでください", "Pick an item to put a character on") }
    static func pickCharacter(for item: String) -> String {
        t("\(item) に当てるキャラクターを選んでください", "Pick a character for \(item)")
    }
    static func current(_ name: String) -> String { t("いまは \(name)", "Now: \(name)") }
    static func nth(_ name: String, _ number: Int) -> String {
        t("\(name) の \(number) 個目", "\(name) #\(number)")
    }
    /// `Doll_com.hnc.Discord` のように、何のための項目かが入っている場合
    static func owned(_ owner: String, _ target: String) -> String {
        t("\(owner)（\(target)）", "\(owner) (\(target))")
    }

    // macOS 自身の項目の名前
    static var clock: String { t("時計", "Clock") }
    static var battery: String { t("バッテリー", "Battery") }
    static var sound: String { t("音量", "Sound") }
    static var controlCenter: String { t("コントロールセンター", "Control Center") }
    static var user: String { t("ユーザ", "User") }
    static var display: String { t("ディスプレイ", "Display") }
    static var audioVideo: String { t("音声と映像", "Audio & Video") }
    static var keyboardBrightness: String { t("キーボードの明るさ", "Keyboard Brightness") }
    static var textInput: String { t("入力ソース", "Input Sources") }
    static var screenMirroring: String { t("画面ミラーリング", "Screen Mirroring") }
    static var nowPlaying: String { t("再生中", "Now Playing") }
    static var focus: String { t("集中モード", "Focus") }
}
