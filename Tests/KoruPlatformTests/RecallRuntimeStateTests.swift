import AppKit
import CoreGraphics
import Foundation
import KoruDomain
import Testing
@testable import KoruPlatform

private final class RuntimeTarget: InsertionTargetAccessing, @unchecked Sendable {
    var snapshot: TargetSnapshot?
    var replacement: (NSRange, String)?
    var allowsDirectReplacement = true
    func currentSnapshot() -> TargetSnapshot? { snapshot }
    func replace(range: NSRange, with text: String) -> Bool { guard allowsDirectReplacement else { return false }; replacement = (range, text); return true }
    func select(range: NSRange) -> Bool { snapshot?.replacementLocation = range.location; snapshot?.replacementLength = range.length; return true }
}

@Test func generatedFocusAndWritingSequencesNeverProduceFocusOnlyOrMidWritingPanels() {
    for initialLength in 0...128 {
        var session = FreshInputSession()
        let initial = String(repeating: "x", count: initialLength)
        session.handle(.focus(value: initial, selectionLocation: initialLength, selectionLength: 0, editable: true, secure: false, excluded: false))
        #expect(session.state == (initialLength == 0 ? .eligibleEmptyStart : .ineligibleUntilFocusChanges))
        if initialLength > 0 { session.handle(.committedCharacter("p", hasQualifyingMatch: true)); #expect(session.state == .ineligibleUntilFocusChanges) }
    }
}

@Test func explicitTypedInsertionRevalidatesDigestAndReplacesOnlyThePrefix() {
    let target = RuntimeTarget()
    let digest = SystemInsertionTarget.digest("pus")
    target.snapshot = .init(processIdentifier: 4, elementToken: "field", replacementLocation: 3, replacementLength: 0, expectedValueDigest: digest)
    let expected = TargetSnapshot(processIdentifier: 4, elementToken: "field", replacementLocation: 0, replacementLength: 3, expectedValueDigest: digest)
    let transaction = InsertionTransaction(invocation: .initialTypedMatch, target: expected, requestedTier: .directAccessibility, explicitlyConfirmed: true)
    let board = NSPasteboard(name: .init("koru-runtime-prefix"))
    #expect(InsertionCoordinator(target: target, pasteboard: board).insert("Push to GitHub", transaction: transaction, capability: .full) == .inserted(.directAccessibility))
    #expect(target.replacement?.0 == NSRange(location: 0, length: 3))
}

@Test func mutationCaretMovementAndMissingConfirmationNeverInsert() {
    let target = RuntimeTarget(); let digest = SystemInsertionTarget.digest("pus")
    let expected = TargetSnapshot(processIdentifier: 4, elementToken: "field", replacementLocation: 0, replacementLength: 3, expectedValueDigest: digest)
    target.snapshot = .init(processIdentifier: 4, elementToken: "field", replacementLocation: 2, replacementLength: 0, expectedValueDigest: digest)
    let board = NSPasteboard(name: .init("koru-runtime-fault")); let coordinator = InsertionCoordinator(target: target, pasteboard: board)
    #expect(coordinator.insert("unsafe", transaction: .init(invocation: .initialTypedMatch, target: expected, requestedTier: .directAccessibility, explicitlyConfirmed: true), capability: .full) == .cancelledTargetChanged)
    #expect(coordinator.insert("unsafe", transaction: .init(invocation: .initialTypedMatch, target: expected, requestedTier: .directAccessibility, explicitlyConfirmed: false), capability: .full) == .cancelledUnconfirmed)
    #expect(target.replacement == nil)
}

@Test func directAXFailureFallsThroughToUndoCompatiblePasteBeforeCopyOnly() {
    let target = RuntimeTarget(); target.allowsDirectReplacement = false; let digest = SystemInsertionTarget.digest("pus")
    target.snapshot = .init(processIdentifier: 4, elementToken: "field", replacementLocation: 3, replacementLength: 0, expectedValueDigest: digest)
    let expected = TargetSnapshot(processIdentifier: 4, elementToken: "field", replacementLocation: 0, replacementLength: 3, expectedValueDigest: digest)
    let transaction = InsertionTransaction(invocation: .initialTypedMatch, target: expected, requestedTier: .directAccessibility, explicitlyConfirmed: true)
    let board = NSPasteboard(name: .init("koru-runtime-tier-fallback"))
    #expect(InsertionCoordinator(target: target, pasteboard: board, postPaste: { true }).insert("Push", transaction: transaction, capability: .full) == .inserted(.pasteboardAndPaste))
    #expect(board.string(forType: .string) == "Push")
}

@Test func emptyManualSearchUsesTheSameBoundedIndexPath() async {
    let index = InMemorySearchIndex(); let older = SavedItem(title: "Older", behavior: .savedText, plainContent: "one", updatedAt: Date(timeIntervalSince1970: 1)); let newer = SavedItem(title: "Newer", behavior: .savedText, plainContent: "two", updatedAt: Date(timeIntervalSince1970: 90_000))
    await index.rebuild(savedItems: [older, newer], clipboardEvents: [])
    let results = await index.search("", scope: .saved, limit: 8, includeAllWhenEmpty: true)
    #expect(results.map(\.title) == ["Newer", "Older"])
    #expect(await index.search("", scope: .saved).isEmpty)
}

@Test func eventTapClassifiesPanelCommandsWithoutTreatingFocusAsInput() {
    func event(_ key: Int64, text: String? = nil) -> CGEvent {
        let source = CGEventSource(stateID: .privateState)!; let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: true)!
        if let text { var units = Array(text.utf16); event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units) }
        return event
    }
    #expect(TypedEventTapService.message(event(36)) == .confirm)
    #expect(TypedEventTapService.message(event(53)) == .dismiss)
    #expect(TypedEventTapService.message(event(125)) == .navigation(1))
    #expect(TypedEventTapService.message(event(0, text: "p")) == .character("p"))
}
