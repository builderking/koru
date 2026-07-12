import AppKit

// Generates the macOS app icon (AppIcon.icns) with the koru fern-spiral mark.
// Usage: swift scripts/generate-app-icon.swift <output-dir>
// Writes <output-dir>/AppIcon.icns and <output-dir>/AppIcon-preview.png.

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

// Brand palette shared with website/scripts/generate-icons.swift.
let gradientTop = NSColor(calibratedRed: 0.075, green: 0.573, blue: 0.376, alpha: 1) // #13925f
let gradientBottom = NSColor(calibratedRed: 0.024, green: 0.318, blue: 0.216, alpha: 1) // #065137

// All drawing happens in a 1024x1024 design space and is scaled per output size.
let designSize: CGFloat = 1024

func korus(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func spiralPath() -> NSBezierPath {
    // Tapered logarithmic spiral: a band between an outer and inner edge,
    // capped with a round tip at each end. Reads as an unfurling fern frond.
    let pole = korus(548, 528)
    let sweep: CGFloat = 2.05 * 2 * .pi
    let radiusOuter: CGFloat = 292
    let radiusInner: CGFloat = 30
    let widthOuter: CGFloat = 92
    let widthInner: CGFloat = 24
    let startAngle: CGFloat = -0.62 * .pi
    let growth = log(radiusInner / radiusOuter) / sweep
    let steps = 720

    var outerEdge: [CGPoint] = []
    var innerEdge: [CGPoint] = []
    var centerline: [CGPoint] = []
    var halfWidths: [CGFloat] = []
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps)
        let angle = startAngle + t * sweep
        let radius = radiusOuter * exp(growth * t * sweep)
        let width = widthOuter + (widthInner - widthOuter) * pow(t, 0.85)
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let center = korus(pole.x + radius * direction.x, pole.y + radius * direction.y)
        centerline.append(center)
        halfWidths.append(width / 2)
        outerEdge.append(korus(pole.x + (radius + width / 2) * direction.x, pole.y + (radius + width / 2) * direction.y))
        innerEdge.append(korus(pole.x + (radius - width / 2) * direction.x, pole.y + (radius - width / 2) * direction.y))
    }

    let path = NSBezierPath()
    path.move(to: outerEdge[0])
    outerEdge.dropFirst().forEach { path.line(to: $0) }
    innerEdge.reversed().forEach { path.line(to: $0) }
    path.close()

    func cap(at point: CGPoint, radius: CGFloat) {
        path.appendOval(in: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
    cap(at: centerline.first!, radius: halfWidths.first!)
    cap(at: centerline.last!, radius: halfWidths.last!)
    // The koru "head": a slightly larger dot the frond curls around.
    cap(at: pole, radius: widthInner * 1.9)
    return path
}

func drawIcon() {
    // macOS icon grid: 824pt squircle centered on the 1024pt canvas.
    let tile = NSRect(x: 100, y: 100, width: designSize - 200, height: designSize - 200)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    NSGradient(starting: gradientTop, ending: gradientBottom)?.draw(in: squircle, angle: -90)
    NSColor.white.setFill()
    spiralPath().fill()
}

func render(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw NSError(domain: "KoruAssets", code: 1) }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / designSize)
    transform.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoruAssets", code: 2)
    }
    return png
}

let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(pixels: 512).write(to: output.appendingPathComponent("AppIcon-preview.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
try FileManager.default.removeItem(at: iconset)
print("wrote \(output.appendingPathComponent("AppIcon.icns").path)")
