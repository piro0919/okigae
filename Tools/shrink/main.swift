// 絵をメニューバーの実寸まで縮めて、明るい地と暗い地の両方に並べる。
//
//   swiftc -O -target arm64-apple-macos14.0 -framework AppKit \
//     -o build/shrink Tools/shrink/main.swift
//   ./build/shrink Resources/Characters/yuki.png docs/preview-yuki.png
//
// 輪郭が薄いと、暗いバーに沈むか明るい壁紙に溶けるかのどちらかで潰れる。
// 縮めた姿を等倍と拡大で並べておけば、置く前に分かる。
import AppKit

guard CommandLine.arguments.count >= 3 else {
    print("使い方: shrink <入力.png> <出力.png>")
    exit(1)
}

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: input) else {
    print("読めませんでした: \(input)")
    exit(1)
}

// メニューバーの項目の高さ。Retina なので実画素は倍。
let side = 22
let scale = 2
let actual = side * scale
// 等倍の隣に、粗が見えるよう拡大したものを置く
let zoom = 4
let padding = 12
let backgrounds: [(name: String, color: NSColor)] = [
    ("暗", NSColor(calibratedWhite: 0.16, alpha: 1)),
    ("明", NSColor(calibratedRed: 0.42, green: 0.55, blue: 0.63, alpha: 1)),
]

// 行の高さは拡大したほうに合わせ、等倍のものはその中で縦中央に置く
let rowHeight = actual * zoom + padding * 2
let width = padding * 3 + actual + actual * zoom
let height = rowHeight * backgrounds.count

guard let canvas = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: width, pixelsHigh: height,
                                    bitsPerSample: 8, samplesPerPixel: 4,
                                    hasAlpha: true, isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0, bitsPerPixel: 0)
else {
    print("画布を作れませんでした")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
NSGraphicsContext.current?.imageInterpolation = .high

for (index, background) in backgrounds.enumerated() {
    let y = height - rowHeight * (index + 1)
    background.color.setFill()
    NSRect(x: 0, y: y, width: width, height: rowHeight).fill()

    let centred = y + (rowHeight - actual) / 2
    image.draw(in: NSRect(x: padding, y: centred, width: actual, height: actual),
               from: .zero, operation: .sourceOver, fraction: 1)
    image.draw(in: NSRect(x: padding * 2 + actual, y: y + padding,
                          width: actual * zoom, height: actual * zoom),
               from: .zero, operation: .sourceOver, fraction: 1)
}

NSGraphicsContext.restoreGraphicsState()

guard let data = canvas.representation(using: .png, properties: [:]) else {
    print("書き出せませんでした")
    exit(1)
}
try data.write(to: URL(fileURLWithPath: output))
print("\(output) に \(side) ポイントの見本を書きました")
