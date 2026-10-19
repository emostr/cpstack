// Renders the background of the CPStack disk image window at 1x and 2x.
// Usage: swift Scripts/make-dmg-background.swift <output-dir>
// Produces background.png and background@2x.png; build-dmg.sh merges them into a HiDPI TIFF.
import AppKit

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let size = CGSize(width: 640, height: 400)
// Icon centers used by Scripts/dmg-settings.py (top-left origin, like Finder).
let appCenter = CGPoint(x: 170, y: 200)
let applicationsCenter = CGPoint(x: 470, y: 200)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func draw(in rect: CGRect) {
    // Soft vertical gradient with two blurred color blobs — a calm "liquid glass" backdrop.
    NSGradient(colors: [color(0xF5F7FF), color(0xE6EBFF)])!.draw(in: rect, angle: -90)
    for (center, radius, tint) in [
        (CGPoint(x: 90, y: 330), 260.0, color(0x8FB4FF, 0.35)),
        (CGPoint(x: 560, y: 60), 280.0, color(0xB59CFF, 0.30)),
    ] {
        NSGradient(colors: [tint, tint.withAlphaComponent(0)])!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }

    // Frosted card behind the two icons.
    let card = NSBezierPath(roundedRect: CGRect(x: 40, y: 92, width: 560, height: 210), xRadius: 34, yRadius: 34)
    color(0xFFFFFF, 0.55).setFill()
    card.fill()
    color(0xFFFFFF, 0.9).setStroke()
    card.lineWidth = 1
    card.stroke()

    // Arrow from the app to Applications (flip y: Finder coordinates are top-left).
    let y = size.height - appCenter.y
    let start = CGPoint(x: appCenter.x + 78, y: y)
    let end = CGPoint(x: applicationsCenter.x - 78, y: y)
    let arrow = NSBezierPath()
    arrow.move(to: start)
    arrow.line(to: CGPoint(x: end.x - 6, y: y))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    let dash: [CGFloat] = [0.1, 13]
    arrow.setLineDash(dash, count: dash.count, phase: 0)
    color(0x5468F0, 0.75).setStroke()
    arrow.stroke()

    let head = NSBezierPath()
    head.move(to: CGPoint(x: end.x - 16, y: y + 13))
    head.line(to: CGPoint(x: end.x, y: y))
    head.line(to: CGPoint(x: end.x - 16, y: y - 13))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Titles.
    func text(_ string: String, size fontSize: CGFloat, weight: NSFont.Weight, color textColor: NSColor, y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        NSAttributedString(string: string, attributes: attributes)
            .draw(in: CGRect(x: 0, y: y, width: size.width, height: fontSize * 1.5))
    }
    text("CPStack", size: 26, weight: .bold, color: color(0x1D2150), y: 334)
    text("Перетащите CPStack в папку «Программы»", size: 13, weight: .medium, color: color(0x3B4070), y: 50)
    text("Drag CPStack to the Applications folder", size: 12, weight: .regular, color: color(0x6A6F96), y: 30)
}

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(in: CGRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try render(scale: 1).write(to: outputDir.appending(path: "background.png"))
try render(scale: 2).write(to: outputDir.appending(path: "background@2x.png"))
print("Background written to \(outputDir.path)")
