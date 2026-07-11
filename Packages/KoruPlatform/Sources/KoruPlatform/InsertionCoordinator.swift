import AppKit
import CoreGraphics
import Foundation
import KoruDomain

public enum InsertionOutcome: Equatable, Sendable { case inserted(InsertionTier), copied, cancelledTargetChanged, cancelledUnconfirmed, failedSafely }
public protocol InsertionTargetAccessing: Sendable {
    func currentSnapshot() -> TargetSnapshot?
    func replace(range: NSRange, with text: String) -> Bool
    func select(range: NSRange) -> Bool
}
public final class InsertionCoordinator: @unchecked Sendable {
    private let target: InsertionTargetAccessing; private let pasteboard: NSPasteboard; private let postPaste: @Sendable () -> Bool
    public init(target: InsertionTargetAccessing, pasteboard: NSPasteboard = .general, postPaste: @escaping @Sendable () -> Bool = InsertionCoordinator.systemPaste) { self.target = target; self.pasteboard = pasteboard; self.postPaste = postPaste }
    public func insert(_ text: String, transaction: InsertionTransaction, capability: CompatibilityCapability) -> InsertionOutcome {
        guard transaction.explicitlyConfirmed else { return .cancelledUnconfirmed }
        guard target.currentSnapshot() == transaction.target else { return .cancelledTargetChanged }
        let range = NSRange(location: transaction.target.replacementLocation, length: transaction.target.replacementLength)
        switch capability {
        case .full: return target.replace(range: range, with: text) ? .inserted(.directAccessibility) : copy(text)
        case .paste:
            guard target.select(range: range), target.currentSnapshot() == transaction.target else { return copy(text) }
            guard write(text), postPaste() else { return .copied }; return .inserted(.pasteboardAndPaste)
        case .copyOnly, .paletteOnly: return copy(text)
        case .blocked: return .failedSafely
        }
    }
    private func copy(_ text: String) -> InsertionOutcome { write(text) ? .copied : .failedSafely }
    private func write(_ text: String) -> Bool { pasteboard.prepareForNewContents(with: .currentHostOnly); pasteboard.setString("dev.builderking.koru", forType: .init("dev.builderking.koru.origin")); return pasteboard.setString(text, forType: .string) }
    public static func systemPaste() -> Bool { guard CGPreflightPostEventAccess(), let source = CGEventSource(stateID: .hidSystemState) else { return false }; let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true); let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false); down?.flags = .maskCommand; up?.flags = .maskCommand; down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap); return down != nil && up != nil }
}
