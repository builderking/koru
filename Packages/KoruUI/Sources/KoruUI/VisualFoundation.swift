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
