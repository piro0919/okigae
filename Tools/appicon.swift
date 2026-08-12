// 生成したアプリアイコンを、macOS の角丸に沿って切り抜く。
//
//   swift Tools/appicon.swift <入力.png> <出力.png>
//
// 生成物は角の外まで地の色で塗られてくる。そのまま .icns にすると Dock で
// 四角いまま出るので、外側を透過にする。角丸の半径は macOS の慣例に近い
// 22.37% を使う。

import AppKit

guard CommandLine.arguments.count >= 3 else {
    print("使い方: swift Tools/appicon.swift <入力.png> <出力.png>")
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

let side = min(source.pixelsWide, source.pixelsHigh)

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

let bounds = NSRect(x: 0, y: 0, width: side, height: side)
let radius = CGFloat(side) * 0.2237
NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).addClip()

// 元画像の中央を正方形で切り出し、少し拡大して敷く。
// 生成物は自前の角丸を持っていることが多く、等倍だとその角が内側に残る。
let zoom: CGFloat = 1.08
let offsetX = (source.pixelsWide - side) / 2
let offsetY = (source.pixelsHigh - side) / 2
let enlarged = bounds.insetBy(dx: -bounds.width * (zoom - 1) / 2,
                              dy: -bounds.height * (zoom - 1) / 2)
source.draw(in: enlarged,
            from: NSRect(x: offsetX, y: offsetY, width: side, height: side),
            operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
NSGraphicsContext.restoreGraphicsState()

guard let data = canvas.representation(using: .png, properties: [:]) else {
    print("書き出せませんでした")
    exit(1)
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("\(inputPath) → \(outputPath) \(side)x\(side)、角丸で切り抜き")
