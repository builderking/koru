import AppKit
import SwiftUI

public enum KoruSpacing { public static let compact: CGFloat = 6; public static let standard: CGFloat = 12; public static let section: CGFloat = 20 }
public enum KoruCorners { public static let compact: CGFloat = 8; public static let panel: CGFloat = 14 }
public enum KoruMotion { public static let functionalDuration = 0.12 }

public struct AdaptiveSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    public init() {}
    public func body(content: Content) -> some View {
        content
            .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: KoruCorners.panel).stroke(contrast == .increased ? Color.primary : Color(nsColor: .separatorColor), lineWidth: contrast == .increased ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: KoruCorners.panel))
    }
}

public extension View { func koruAdaptiveSurface() -> some View { modifier(AdaptiveSurface()) } }

/// Caches app windows by key so repeat invocations reuse a single window. Windows are created with
/// `isReleasedWhenClosed = false`: AppKit must never deallocate a window this cache still references,
/// otherwise the next lookup retains a dangling pointer and crashes.
@MainActor public final class WindowReuseCache {
    private var windows: [String: NSWindow] = [:]
    public init() {}
    public func window(key: String, title: String, size: NSSize, view: AnyView) -> NSWindow {
        if let window = windows[key] { return window }
        let window = NSWindow(contentRect: .init(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = title
        window.contentView = NSHostingView(rootView: view)
        window.center()
        windows[key] = window
        return window
    }
}
