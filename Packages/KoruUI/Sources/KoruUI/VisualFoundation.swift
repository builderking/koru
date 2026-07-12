import AppKit
import SwiftUI

public enum KoruSpacing { public static let compact: CGFloat = 6; public static let standard: CGFloat = 12; public static let section: CGFloat = 20 }
public enum KoruCorners { public static let compact: CGFloat = 8; public static let panel: CGFloat = 14 }
public enum KoruMotion { public static let functionalDuration = 0.12 }

/// The exact adaptive palette used by the Koru website.
///
/// Native AppKit control mechanics remain intact while window backgrounds, text hierarchy, branded
/// accents, and custom raised surfaces use one source of truth shared with the website.
public enum KoruColors {
    public static let canvasNSColor = adaptiveNSColor(light: 0xFAFAF7, dark: 0x0E110F)
    public static let canvasRaisedNSColor = adaptiveNSColor(light: 0xFFFFFF, dark: 0x151A16)
    public static let canvas = Color(nsColor: canvasNSColor)
    public static let canvasRaised = Color(nsColor: canvasRaisedNSColor)
    public static let ink = adaptive(light: 0x161A17, dark: 0xF0F3EE)
    public static let muted = adaptive(light: 0x59615B, dark: 0xA7B1A9)
    public static let faint = adaptive(light: 0x7F8781, dark: 0x85908A)
    public static let panel = adaptive(light: 0xF0F1EC, dark: 0x1A1F1B)
    public static let panelStrong = adaptive(light: 0xE6E8E1, dark: 0x232924)
    public static let accent = adaptive(light: 0x0C7A50, dark: 0x55CF9C)
    public static let accentHover = adaptive(light: 0x095F3E, dark: 0x7DE0B6)
    public static let accentSoft = adaptive(light: 0xE2F1E9, dark: 0x163327)
    public static let accentInk = adaptive(light: 0xFFFFFF, dark: 0x07130D)
    public static let hairline = adaptive(light: 0xE4E6DF, dark: 0x262C27)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: adaptiveNSColor(light: light, dark: dark))
    }

    private static func adaptiveNSColor(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            rgb(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        }
    }

    private static func rgb(_ value: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

public struct KoruWindowRoot: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(KoruColors.ink, KoruColors.muted)
            .tint(KoruColors.accent)
            .scrollContentBackground(.hidden)
            .background {
                KoruColors.canvas
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(contrast == .increased ? KoruColors.ink : KoruColors.hairline)
                            .frame(height: contrast == .increased ? 2 : 1)
                    }
                    .ignoresSafeArea()
            }
    }
}

public struct AdaptiveSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    public init() {}
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: KoruCorners.panel)
        content
            .foregroundStyle(KoruColors.ink, KoruColors.muted)
            .tint(KoruColors.accent)
            .background {
                if reduceTransparency {
                    shape.fill(KoruColors.canvasRaised)
                } else {
                    shape.fill(.thinMaterial)
                    shape.fill(KoruColors.canvasRaised.opacity(0.76))
                }
            }
            .overlay {
                shape.stroke(
                    contrast == .increased ? KoruColors.ink : KoruColors.hairline,
                    lineWidth: contrast == .increased ? 2 : 1
                )
            }
            .clipShape(shape)
    }
}

public extension View {
    func koruWindowRoot() -> some View { modifier(KoruWindowRoot()) }
    func koruAdaptiveSurface() -> some View { modifier(AdaptiveSurface()) }
}

/// Caches app windows by key so repeat invocations reuse a single window. Windows are created with
/// `isReleasedWhenClosed = false`: AppKit must never deallocate a window this cache still references,
/// otherwise the next lookup retains a dangling pointer and crashes.
@MainActor public final class WindowReuseCache: NSObject, NSWindowDelegate {
    private var windows: [String: NSWindow] = [:]
    public override init() { super.init() }
    public func window(key: String, title: String, size: NSSize, view: AnyView) -> NSWindow {
        if let window = windows[key] { return window }
        let window = NSWindow(contentRect: .init(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = title
        window.backgroundColor = KoruColors.canvasNSColor
        window.delegate = self
        window.contentView = NSHostingView(rootView: AnyView(view.koruWindowRoot()))
        window.center()
        windows[key] = window
        return window
    }

    public func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using screenRect: NSRect) -> NSRect {
        sheet.backgroundColor = KoruColors.canvasRaisedNSColor
        return screenRect
    }
}
