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
    /// Attempts only a revalidated, verifiable Accessibility mutation. Automatic recall uses this
    /// before keyboard synthesis so WebKit inputs do not depend on an Edit/Paste responder route.
    public func insertDirectAccessibility(_ text: String, transaction: InsertionTransaction) -> InsertionOutcome {
        guard transaction.explicitlyConfirmed else { return .cancelledUnconfirmed }
        guard matches(target.currentSnapshot(), transaction.target, invocation: transaction.invocation) else { return .cancelledTargetChanged }
        let range = NSRange(location: transaction.target.replacementLocation, length: transaction.target.replacementLength)
        guard target.replace(range: range, with: text) else {
            restoreCaretAfterFailedPaste(range: range, expected: transaction.target)
            return .failedSafely
        }
        if replacementApplied(range: range, text: text, originalDigest: transaction.target.expectedValueDigest) {
            return .inserted(.directAccessibility)
        }
        let current = target.currentSnapshot()
        if current?.expectedValueDigest != transaction.target.expectedValueDigest { return .cancelledTargetChanged }
        restoreCaretAfterFailedPaste(range: range, expected: transaction.target)
        return .failedSafely
    }
    public func insert(_ text: String, transaction: InsertionTransaction, capability: CompatibilityCapability) -> InsertionOutcome {
        guard transaction.explicitlyConfirmed else { return .cancelledUnconfirmed }
        guard matches(target.currentSnapshot(), transaction.target, invocation: transaction.invocation) else { return .cancelledTargetChanged }
        let range = NSRange(location: transaction.target.replacementLocation, length: transaction.target.replacementLength)
        switch capability {
        case .full:
            // Chromium and Electron web content acknowledge kAXSelectedText writes without applying
            // them; trust direct replacement only when the caret proves the text actually landed.
            let direct = insertDirectAccessibility(text, transaction: transaction)
            if case .inserted = direct { return direct }
            if case .cancelledTargetChanged = direct { return direct }
            return pasteOrCopy(text, range: range, expected: transaction.target)
        case .paste:
            return pasteOrCopy(text, range: range, expected: transaction.target)
        case .copyOnly, .paletteOnly: return copy(text)
        case .blocked: return .failedSafely
        }
    }
    /// Pastes a non-text representation that the caller has already written to this coordinator's
    /// pasteboard. Target identity and selection are revalidated exactly like the text paste tier.
    public func pastePreparedContent(transaction: InsertionTransaction) -> InsertionOutcome {
        guard transaction.explicitlyConfirmed else { return .cancelledUnconfirmed }
        guard matches(target.currentSnapshot(), transaction.target, invocation: transaction.invocation) else { return .cancelledTargetChanged }
        let range = NSRange(location: transaction.target.replacementLocation, length: transaction.target.replacementLength)
        guard target.select(range: range), matchesSelected(target.currentSnapshot(), transaction.target) else {
            restoreCaretAfterFailedPaste(range: range, expected: transaction.target)
            return .cancelledTargetChanged
        }
        guard postPaste() else {
            restoreCaretAfterFailedPaste(range: range, expected: transaction.target)
            return .copied
        }
        return .inserted(.pasteboardAndPaste)
    }
    private func replacementApplied(range: NSRange, text: String, originalDigest: Data?) -> Bool {
        guard let current = target.currentSnapshot() else { return false }
        guard current.replacementLength == 0, current.replacementLocation == range.location + text.utf16.count else { return false }
        // If replacement and trigger have equal UTF-16 lengths, an editor that ignores the write
        // leaves the caret exactly where success would leave it. Require the full-value digest to
        // change as well; different-length replacements are already proven by caret movement.
        return text.utf16.count != range.length || current.expectedValueDigest != originalDigest
    }
    private func copy(_ text: String) -> InsertionOutcome { write(text) ? .copied : .failedSafely }
    private func pasteOrCopy(_ text: String, range: NSRange, expected: TargetSnapshot) -> InsertionOutcome {
        guard target.select(range: range), matchesSelected(target.currentSnapshot(), expected) else {
            restoreCaretAfterFailedPaste(range: range, expected: expected)
            return copy(text)
        }
        guard write(text) else {
            restoreCaretAfterFailedPaste(range: range, expected: expected)
            return .failedSafely
        }
        guard postPaste() else {
            restoreCaretAfterFailedPaste(range: range, expected: expected)
            return .copied
        }
        return .inserted(.pasteboardAndPaste)
    }
    private func restoreCaretAfterFailedPaste(range: NSRange, expected: TargetSnapshot) {
        // AX selection is visible user state. If paste cannot be delivered, put the caret back where
        // it was before Koru selected the trigger. Never touch a newly focused or mutated target.
        guard matchesSelected(target.currentSnapshot(), expected) else { return }
        _ = target.select(range: NSRange(location: NSMaxRange(range), length: 0))
    }
    private func write(_ text: String) -> Bool { KoruPasteboardOrigin.write(text, to: pasteboard) }
    private func matches(_ current: TargetSnapshot?, _ expected: TargetSnapshot, invocation: InvocationMode) -> Bool {
        guard let current, current.processIdentifier == expected.processIdentifier, current.elementToken == expected.elementToken, current.expectedValueDigest == expected.expectedValueDigest else { return false }
        if invocation == .manualRecall { return current.replacementLocation == expected.replacementLocation && current.replacementLength == expected.replacementLength }
        return (current.replacementLocation == expected.replacementLocation + expected.replacementLength && current.replacementLength == 0) || (current.replacementLocation == expected.replacementLocation && current.replacementLength == expected.replacementLength)
    }
    private func matchesSelected(_ current: TargetSnapshot?, _ expected: TargetSnapshot) -> Bool { guard let current else { return false }; return current.processIdentifier == expected.processIdentifier && current.elementToken == expected.elementToken && current.replacementLocation == expected.replacementLocation && current.replacementLength == expected.replacementLength && current.expectedValueDigest == expected.expectedValueDigest }
    static func markedPasteEvents(source: CGEventSource) -> (down: CGEvent, up: CGEvent)? {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return nil }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.setIntegerValueField(.eventSourceUserData, value: TypedEventTapService.syntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: TypedEventTapService.syntheticEventMarker)
        return (down, up)
    }
    public static func systemPaste() -> Bool {
        guard CGPreflightPostEventAccess(), let source = CGEventSource(stateID: .hidSystemState),
              let events = markedPasteEvents(source: source) else { return false }
        // Marking the chord keeps Koru's own listen tap from synchronously routing the synthetic
        // Command-V back through RecallRuntime while the main actor is delivering the paste.
        events.down.post(tap: .cghidEventTap); usleep(25_000); events.up.post(tap: .cghidEventTap)
        return true
    }
}
