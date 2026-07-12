import AppKit
@testable import KoruUI
import SwiftUI
import XCTest

@MainActor
final class VisualFoundationTests: XCTestCase {
    func testWindowSurfaceTokensResolveToTheWebsitePalette() throws {
        XCTAssertEqual(try rgbHex(KoruColors.canvasNSColor, appearance: .aqua), 0xFAFAF7)
        XCTAssertEqual(try rgbHex(KoruColors.canvasNSColor, appearance: .darkAqua), 0x0E110F)
        XCTAssertEqual(try rgbHex(KoruColors.canvasRaisedNSColor, appearance: .aqua), 0xFFFFFF)
        XCTAssertEqual(try rgbHex(KoruColors.canvasRaisedNSColor, appearance: .darkAqua), 0x151A16)
    }

    func testWindowCacheInstallsCanvasBackground() {
        let cache = WindowReuseCache()
        let window = cache.window(
            key: "theme-test",
            title: "Theme Test",
            size: NSSize(width: 320, height: 200),
            view: AnyView(Text("Koru"))
        )
        defer { window.close() }

        XCTAssertEqual(window.backgroundColor, KoruColors.canvasNSColor)
        XCTAssertNotNil(window.contentView)
    }

    func testWindowCacheUsesRaisedBackgroundForAttachedSheets() {
        let cache = WindowReuseCache()
        let window = cache.window(
            key: "sheet-theme-test",
            title: "Sheet Theme Test",
            size: NSSize(width: 320, height: 200),
            view: AnyView(Text("Koru"))
        )
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 140),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheet.isReleasedWhenClosed = false
        defer {
            if window.attachedSheet === sheet { window.endSheet(sheet) }
            sheet.close()
            window.close()
        }

        window.beginSheet(sheet)
        XCTAssertEqual(sheet.backgroundColor, KoruColors.canvasRaisedNSColor)
        window.endSheet(sheet)
    }

    func testRootAndRaisedSurfaceModifiersRenderTogether() {
        let view = AnyView(
            Text("Koru")
                .padding()
                .koruAdaptiveSurface()
                .koruWindowRoot()
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 120)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.width, 0)
        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }

    private func rgbHex(_ color: NSColor, appearance name: NSAppearance.Name) throws -> UInt32 {
        let appearance = try XCTUnwrap(NSAppearance(named: name))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB)
        }
        let rgb = try XCTUnwrap(resolved)
        let red = UInt32((rgb.redComponent * 255).rounded())
        let green = UInt32((rgb.greenComponent * 255).rounded())
        let blue = UInt32((rgb.blueComponent * 255).rounded())
        return red << 16 | green << 8 | blue
    }
}
