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
        guard matches(target.currentSnapshot(), transaction.target, invocation: transaction.invocation) else { return .cancelledTargetChanged }
        let range = NSRange(location: transaction.target.replacementLocation, length: transaction.target.replacementLength)
        switch capability {
        case .full:
            // Chromium and Electron web content acknowledge kAXSelectedText writes without applying
            // them; trust direct replacement only when the caret proves the text actually landed.
            if target.replace(range: range, with: text), replacementApplied(range: range, text: text) { return .inserted(.directAccessibility) }
            return pasteOrCopy(text, range: range, expected: transaction.target)
        case .paste:
            return pasteOrCopy(text, range: range, expected: transaction.target)
        case .copyOnly, .paletteOnly: return copy(text)
        case .blocked: return .failedSafely
        }
    }
    private func replacementApplied(range: NSRange, text: String) -> Bool {
        guard let current = target.currentSnapshot() else { return false }
        return current.replacementLength == 0 && current.replacementLocation == range.location + text.utf16.count
    }
    private func copy(_ text: String) -> InsertionOutcome { write(text) ? .copied : .failedSafely }
    private func pasteOrCopy(_ text: String, range: NSRange, expected: TargetSnapshot) -> InsertionOutcome { guard target.select(range: range), matchesSelected(target.currentSnapshot(), expected), write(text), postPaste() else { return copy(text) }; return .inserted(.pasteboardAndPaste) }
    private func write(_ text: String) -> Bool { pasteboard.prepareForNewContents(with: .currentHostOnly); pasteboard.setString("dev.builderking.koru", forType: .init("dev.builderking.koru.origin")); return pasteboard.setString(text, forType: .string) }
    private func matches(_ current: TargetSnapshot?, _ expected: TargetSnapshot, invocation: InvocationMode) -> Bool {
        guard let current, current.processIdentifier == expected.processIdentifier, current.elementToken == expected.elementToken, current.expectedValueDigest == expected.expectedValueDigest else { return false }
        if invocation == .manualRecall { return current.replacementLocation == expected.replacementLocation && current.replacementLength == expected.replacementLength }
        return (current.replacementLocation == expected.replacementLocation + expected.replacementLength && current.replacementLength == 0) || (current.replacementLocation == expected.replacementLocation && current.replacementLength == expected.replacementLength)
    }
    private func matchesSelected(_ current: TargetSnapshot?, _ expected: TargetSnapshot) -> Bool { guard let current else { return false }; return current.processIdentifier == expected.processIdentifier && current.elementToken == expected.elementToken && current.replacementLocation == expected.replacementLocation && current.replacementLength == expected.replacementLength && current.expectedValueDigest == expected.expectedValueDigest }
    public static func systemPaste() -> Bool { guard CGPreflightPostEventAccess(), let source = CGEventSource(stateID: .hidSystemState) else { return false }; let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true); let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false); down?.flags = .maskCommand; up?.flags = .maskCommand; down?.post(tap: .cghidEventTap); usleep(25_000); up?.post(tap: .cghidEventTap); return down != nil && up != nil }
}
