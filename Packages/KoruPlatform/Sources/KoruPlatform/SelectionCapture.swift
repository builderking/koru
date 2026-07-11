import AppKit
import Foundation

public struct SelectionEvidence: Equatable, Sendable { public var selectedRange: NSRange?; public var valueUTF16Length: Int?; public var bounds: CGRect?; public var contextAllowed: Bool; public var notificationsSupported: Bool; public init(selectedRange: NSRange?, valueUTF16Length: Int?, bounds: CGRect?, contextAllowed: Bool, notificationsSupported: Bool) { self.selectedRange = selectedRange; self.valueUTF16Length = valueUTF16Length; self.bounds = bounds; self.contextAllowed = contextAllowed; self.notificationsSupported = notificationsSupported } }
public struct SelectionIconPolicy: Sendable {
    public init() {}
    public func shouldShow(_ evidence: SelectionEvidence) -> Bool { guard evidence.contextAllowed, evidence.notificationsSupported, let range = evidence.selectedRange, let count = evidence.valueUTF16Length, let bounds = evidence.bounds else { return false }; return range.location == 0 && range.length == count && count > 0 && !bounds.isNull && bounds.width > 0 && bounds.height > 0 }
}
@MainActor public final class SelectionIconController {
    public let panel: KoruPanel; private let action: () -> Void
    public init(action: @escaping () -> Void) { self.action = action; panel = KoruPanel(contentRect: .init(x: 0, y: 0, width: 28, height: 28)); let button = NSButton(image: NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Save selected text to Koru")!, target: nil, action: nil); button.toolTip = "Save selected text to Koru"; button.bezelStyle = .circular; panel.contentView = button; button.target = self; button.action = #selector(activate) }
    public func show(at origin: CGPoint) { panel.setFrameOrigin(origin); panel.orderFrontRegardless() }
    public func dismiss() { panel.orderOut(nil) }
    @objc private func activate() { dismiss(); action() }
}

public struct SaveConfirmationInput: Equatable, Sendable { public enum Source: Equatable, Sendable { case service, accessibilityShortcut, selectionIcon }; public var plainText: String; public var richText: Data?; public var source: Source }
@MainActor public protocol SaveConfirmationReceiving: AnyObject { func receive(_ input: SaveConfirmationInput) }
@MainActor public final class SelectionServiceProcessor {
    private weak var receiver: SaveConfirmationReceiving?
    public init(receiver: SaveConfirmationReceiving) { self.receiver = receiver }
    public func process(_ pasteboard: NSPasteboard) -> String? {
        let text = pasteboard.string(forType: .string); let rich = pasteboard.data(forType: .rtf)
        guard let text, !text.isEmpty else { return "Koru received no supported text." }
        receiver?.receive(.init(plainText: text, richText: rich, source: .service)); return nil
    }
}

public protocol SelectedTextReading { func selectedText() -> Result<String, AXInspectionError> }
public enum SaveSelectionShortcutOutcome: Equatable { case opened, useService, blocked }
@MainActor public struct SaveSelectionShortcut {
    private let reader: SelectedTextReading; private weak var receiver: SaveConfirmationReceiving?
    public init(reader: SelectedTextReading, receiver: SaveConfirmationReceiving) { self.reader = reader; self.receiver = receiver }
    public func invoke(context: ContextDecision) -> SaveSelectionShortcutOutcome {
        guard case .allowed = context else { return .blocked }
        guard case let .success(text) = reader.selectedText(), !text.isEmpty else { return .useService }
        receiver?.receive(.init(plainText: text, richText: nil, source: .accessibilityShortcut)); return .opened
    }
}
