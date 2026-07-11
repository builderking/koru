import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func makeIcon(size: Int, filename: String) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.969, green: 0.961, blue: 0.937, alpha: 1).setFill()
    bounds.fill()
    let inset = CGFloat(size) * 0.08
    let tile = bounds.insetBy(dx: inset, dy: inset)
    NSColor(calibratedRed: 0.141, green: 0.420, blue: 0.294, alpha: 1).setFill()
    NSBezierPath(roundedRect: tile, xRadius: CGFloat(size) * 0.21, yRadius: CGFloat(size) * 0.21).fill()
    let font = NSFont.systemFont(ofSize: CGFloat(size) * 0.56, weight: .bold)
    let text = NSString(string: "K")
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = text.size(withAttributes: attributes)
    let point = NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: (CGFloat(size) - textSize.height) / 2 + CGFloat(size) * 0.025)
    text.draw(at: point, withAttributes: attributes)
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoruIcons", code: 1)
    }
    try png.write(to: output.appendingPathComponent(filename))
}

try makeIcon(size: 32, filename: "favicon-32.png")
try makeIcon(size: 180, filename: "apple-touch-icon.png")
try makeIcon(size: 192, filename: "icon-192.png")
try makeIcon(size: 512, filename: "icon-512.png")
