// Renders the CPStack app icon and packs it into an .icns file.
// Usage: swift Scripts/make-icon.swift <output.icns>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Draws the icon on a 1024×1024 canvas (origin bottom-left).
func drawIcon(_ ctx: CGContext) {
    // Body on Apple's icon grid: 824 pt square with a continuous-looking corner.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = roundedRect(body, 186)

    // Drop shadow under the body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x2B3BD8))
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    linearGradient(ctx, [color(0x6FA8FF), color(0x4C6BFF), color(0x3A2FC9)],
                   from: CGPoint(x: 300, y: 924), to: CGPoint(x: 724, y: 100))
    // Soft light from the top.
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [color(0xFFFFFF, 0.35), color(0xFFFFFF, 0)] as CFArray, locations: nil)!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 960), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 960), endRadius: 620, options: [])
    ctx.restoreGState()

    // Stack of clipboard cards: two translucent cards behind a frosted front card.
    let cardWidth: CGFloat = 540, cardHeight: CGFloat = 360
    let layers: [(dy: CGFloat, inset: CGFloat, alpha: CGFloat)] = [(150, 70, 0.28), (75, 35, 0.5)]
    for layer in layers {
        let rect = CGRect(x: 512 - cardWidth / 2 + layer.inset, y: 250 + layer.dy,
                          width: cardWidth - layer.inset * 2, height: cardHeight)
        ctx.addPath(roundedRect(rect, 64))
        ctx.setFillColor(color(0xFFFFFF, layer.alpha))
        ctx.fillPath()
    }

    let front = CGRect(x: 512 - cardWidth / 2, y: 250, width: cardWidth, height: cardHeight)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: color(0x10125A, 0.35))
    ctx.addPath(roundedRect(front, 64))
    ctx.setFillColor(color(0xFFFFFF, 0.96))
    ctx.fillPath()
    ctx.restoreGState()

    // Glass sheen on the front card.
    ctx.saveGState()
    ctx.addPath(roundedRect(front, 64))
    ctx.clip()
    linearGradient(ctx, [color(0xFFFFFF, 0), color(0xDDE6FF, 0.6)],
                   from: CGPoint(x: 0, y: front.maxY), to: CGPoint(x: 0, y: front.minY))
    ctx.restoreGState()

    // Text lines on the front card.
    let lines: [(width: CGFloat, alpha: CGFloat)] = [(360, 0.9), (420, 0.45), (280, 0.45)]
    for (index, line) in lines.enumerated() {
        let rect = CGRect(x: front.minX + 64, y: front.maxY - 100 - CGFloat(index) * 82, width: line.width, height: 40)
        ctx.addPath(roundedRect(rect, 20))
        ctx.setFillColor(color(0x4C5BEF, line.alpha))
        ctx.fillPath()
    }
}

func render(size: Int) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appending(path: "CPStack-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appending(path: "icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appending(path: "icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Icon written to \(output.path)")
