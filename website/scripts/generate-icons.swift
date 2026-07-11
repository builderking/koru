import AppKit

// Generates placeholder brand assets (favicons, touch icons, and the social og image).
// Usage: swift generate-icons.swift <public-dir>
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconsDir = output.appendingPathComponent("icons", isDirectory: true)
try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)

let canvas = NSColor(calibratedRed: 0.980, green: 0.980, blue: 0.969, alpha: 1) // #fafaf7
let accent = NSColor(calibratedRed: 0.047, green: 0.478, blue: 0.314, alpha: 1) // #0c7a50
let ink = NSColor(calibratedRed: 0.086, green: 0.102, blue: 0.090, alpha: 1) // #161a17
let mutedInk = NSColor(calibratedRed: 0.349, green: 0.380, blue: 0.357, alpha: 1) // #59615b

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoruAssets", code: 1)
    }
    try png.write(to: url)
}

func makeIcon(size: Int, filename: String) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    canvas.setFill()
    bounds.fill()
    let inset = CGFloat(size) * 0.08
    let tile = bounds.insetBy(dx: inset, dy: inset)
    accent.setFill()
    NSBezierPath(roundedRect: tile, xRadius: CGFloat(size) * 0.21, yRadius: CGFloat(size) * 0.21).fill()
    let font = NSFont.systemFont(ofSize: CGFloat(size) * 0.56, weight: .bold)
    let text = NSString(string: "K")
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = text.size(withAttributes: attributes)
    let point = NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: (CGFloat(size) - textSize.height) / 2 + CGFloat(size) * 0.025)
    text.draw(at: point, withAttributes: attributes)
    image.unlockFocus()
    try writePNG(image, to: iconsDir.appendingPathComponent(filename))
}

func makeSocialImage() throws {
    let width: CGFloat = 1200, height: CGFloat = 630
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)
    canvas.setFill()
    bounds.fill()

    // Soft accent wash in the upper right.
    if let gradient = NSGradient(starting: accent.withAlphaComponent(0.14), ending: canvas.withAlphaComponent(0)) {
        gradient.draw(fromCenter: NSPoint(x: width * 0.85, y: height * 0.9), radius: 0,
                      toCenter: NSPoint(x: width * 0.85, y: height * 0.9), radius: 620, options: [])
    }

    // Glyph tile.
    let tileSize: CGFloat = 108
    let tile = NSRect(x: 96, y: height - 96 - tileSize, width: tileSize, height: tileSize)
    accent.setFill()
    NSBezierPath(roundedRect: tile, xRadius: 24, yRadius: 24).fill()
    let glyph = NSString(string: "K")
    let glyphAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 62, weight: .bold), .foregroundColor: NSColor.white,
    ]
    let glyphSize = glyph.size(withAttributes: glyphAttributes)
    glyph.draw(at: NSPoint(x: tile.midX - glyphSize.width / 2, y: tile.midY - glyphSize.height / 2 + 3), withAttributes: glyphAttributes)

    let name = NSString(string: "Koru")
    name.draw(at: NSPoint(x: tile.maxX + 30, y: tile.midY - 30), withAttributes: [
        .font: NSFont.systemFont(ofSize: 52, weight: .bold), .foregroundColor: ink, .kern: -1.0,
    ])

    let headline = NSString(string: "Never rewrite what you\nalready got right.")
    let headlineStyle = NSMutableParagraphStyle()
    headlineStyle.lineHeightMultiple = 0.98
    headline.draw(in: NSRect(x: 96, y: 160, width: width - 192, height: 260), withAttributes: [
        .font: NSFont.systemFont(ofSize: 84, weight: .bold), .foregroundColor: ink, .kern: -2.5,
        .paragraphStyle: headlineStyle,
    ])

    let tagline = NSString(string: "Writing memory for your Mac. Free download · Local & private")
    tagline.draw(at: NSPoint(x: 96, y: 92), withAttributes: [
        .font: NSFont.systemFont(ofSize: 32, weight: .medium), .foregroundColor: mutedInk,
    ])

    image.unlockFocus()
    try writePNG(image, to: output.appendingPathComponent("og.png"))
}

try makeIcon(size: 32, filename: "favicon-32.png")
try makeIcon(size: 180, filename: "apple-touch-icon.png")
try makeIcon(size: 192, filename: "icon-192.png")
try makeIcon(size: 512, filename: "icon-512.png")
try makeSocialImage()
