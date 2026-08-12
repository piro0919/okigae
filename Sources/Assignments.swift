import AppKit

/// どの項目にどの絵を当てるか。
///
/// 鍵は `StatusItems.resolved()` が返すもので、`io.kkweb.konechi#0` のような形。
/// ウィンドウ ID は再起動で変わるため使えず、バンドル ID だけでは同じアプリが
/// 複数の項目を出す場合に区別できないので、通し番号を足している。
enum Assignments {
    /// 設定と絵の置き場。
    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Okigae", isDirectory: true)
    }()

    static var facesDirectory: URL { supportDirectory.appendingPathComponent("Faces", isDirectory: true) }
    static var file: URL { supportDirectory.appendingPathComponent("assignments.json") }

    /// 鍵から絵の名前への対応。絵は Faces/<名前>.png に置く。
    private(set) static var table: [String: String] = [:]

    private static var cache: [String: NSImage] = [:]

    static func prepareDirectories() {
        for directory in [supportDirectory, facesDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// 同梱の絵を Faces へ書き出す。同じ名前が既にあれば触らない。
    ///
    /// 配布した相手の環境には何も無いので、初回は選べる絵が一つも無い状態から始まる。
    /// アプリの中に 8 体持たせて、初回起動で置く。
    static func installBundledFaces() {
        prepareDirectories()
        guard let bundled = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "Faces") else {
            return
        }
        for source in bundled {
            let destination = facesDirectory.appendingPathComponent(source.lastPathComponent)
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            try? FileManager.default.copyItem(at: source, to: destination)
        }
    }

    static func load() {
        prepareDirectories()
        installBundledFaces()
        cache.removeAll()
        guard let data = try? Data(contentsOf: file),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            table = [:]
            return
        }
        table = parsed
    }

    static func save() {
        prepareDirectories()
        guard let data = try? JSONSerialization.data(withJSONObject: table,
                                                     options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? data.write(to: file)
    }

    static func set(face: String?, for key: String) {
        table[key] = face
        save()
    }

    /// 鍵に対応する絵。無ければ nil。
    static func image(for key: String) -> NSImage? {
        guard let name = table[key] else { return nil }
        if let cached = cache[name] { return cached }
        let url = facesDirectory.appendingPathComponent("\(name).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }

    /// Faces に置かれている絵の一覧。
    static func availableFaces() -> [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: facesDirectory.path)) ?? []
        return contents
            .filter { $0.hasSuffix(".png") }
            .map { String($0.dropLast(4)) }
            .sorted()
    }
}
