// 絵の透明な余白を落として、正方形に整える。
//
//   swift Tools/square.swift <入力.png> <出力.png>
//
// メニューバーの項目は幅が 18 ポイント程度しかないものもあり、横長の絵は
// 幅で頭打ちになって小さくなる。正方形にしておくと高さを使い切れる。

import AppKit

guard CommandLine.arguments.count >= 3 else {
    print("使い方: swift Tools/square.swift <入力.png> <出力.png>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: inputPath),
      let tiff = image.tiffRepresentation,
      let source = NSBitmapImageRep(data: tiff)
else {
    print("読めませんでした: \(inputPath)")
    exit(1)
}

let width = source.pixelsWide
let height = source.pixelsHigh

// 不透明な画素の外接矩形を求める。
var minX = width, minY = height, maxX = -1, maxY = -1
for y in 0..<height {
    for x in 0..<width {
        guard let color = source.colorAt(x: x, y: y), color.alphaComponent > 0.02 else { continue }
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}

guard maxX >= minX, maxY >= minY else {
    print("中身がありません: \(inputPath)")
    exit(1)
}

let contentWidth = maxX - minX + 1
let contentHeight = maxY - minY + 1
let side = max(contentWidth, contentHeight)

// 正方形の画布の中央へ置く。
guard let canvas = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: side, pixelsHigh: side,
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
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()

let offsetX = (side - contentWidth) / 2
let offsetY = (side - contentHeight) / 2
// NSBitmapImageRep の y は上が 0、描画座標は下が 0 なので反転して合わせる。
let flippedMinY = height - maxY - 1
source.draw(in: NSRect(x: offsetX, y: offsetY, width: contentWidth, height: contentHeight),
            from: NSRect(x: minX, y: flippedMinY, width: contentWidth, height: contentHeight),
            operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
NSGraphicsContext.restoreGraphicsState()

guard let data = canvas.representation(using: .png, properties: [:]) else {
    print("書き出せませんでした")
    exit(1)
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("\(inputPath) \(width)x\(height) → \(outputPath) \(side)x\(side)")
