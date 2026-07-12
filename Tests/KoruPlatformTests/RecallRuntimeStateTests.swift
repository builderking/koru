import AppKit
import CoreGraphics
import Foundation
import KoruDomain
import SwiftUI
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

private struct NoFocusInspector: AccessibilityInspecting {
    func focusedTarget() -> Result<AXTargetSnapshot, AXInspectionError> { .failure(.noFocusedElement) }
}

@MainActor private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
}

@MainActor @Test func shortcutOpenedPanelListsHydratedSavedItemsWithEmptyQuery() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    let newer = SavedItem(title: "Alpha one", behavior: .savedText, plainContent: "one", updatedAt: Date(timeIntervalSince1970: 90_000))
    let older = SavedItem(title: "Beta two", behavior: .savedText, plainContent: "two", updatedAt: Date(timeIntervalSince1970: 1))
    await index.rebuild(savedItems: [newer, older], clipboardEvents: [])
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false })
    runtime.openManual(scope: .saved)
    try await waitUntil { runtime.resultTitlesForTesting.count == 2 }
    #expect(runtime.panelIsVisibleForTesting)
    #expect(runtime.resultTitlesForTesting == ["Alpha one", "Beta two"])
}

@MainActor @Test func typedCharactersFilterTheShortcutOpenedPanelAndBackspaceRestores() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [
        SavedItem(title: "Alpha one", behavior: .savedText, plainContent: "one", updatedAt: Date(timeIntervalSince1970: 90_000)),
        SavedItem(title: "Beta two", behavior: .savedText, plainContent: "two", updatedAt: Date(timeIntervalSince1970: 1)),
    ], clipboardEvents: [])
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false })
    runtime.openManual(scope: .saved)
    try await waitUntil { runtime.resultTitlesForTesting.count == 2 }
    #expect(runtime.receive(.character("b")))
    try await waitUntil { runtime.resultTitlesForTesting == ["Beta two"] }
    #expect(runtime.queryForTesting == "b")
    #expect(runtime.resultTitlesForTesting == ["Beta two"])
    #expect(runtime.panelIsVisibleForTesting)
    #expect(runtime.receive(.backspace))
    try await waitUntil { runtime.resultTitlesForTesting.count == 2 }
    #expect(runtime.queryForTesting.isEmpty)
    #expect(runtime.resultTitlesForTesting == ["Alpha one", "Beta two"])
    #expect(runtime.receive(.dismiss))
    #expect(!runtime.panelIsVisibleForTesting)
}

private final class PointerBox { var location: CGPoint = .zero }

private final class ScriptedFocusInspector: AccessibilityInspecting, @unchecked Sendable {
    var snapshot: AXTargetSnapshot
    init(snapshot: AXTargetSnapshot) { self.snapshot = snapshot }
    func focusedTarget() -> Result<AXTargetSnapshot, AXInspectionError> { .success(snapshot) }
}

@MainActor @Test func burstTypedCharactersWithinTheCommitWindowStillOpenThePanel() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Davood", behavior: .savedText, plainContent: "signature")], clipboardEvents: [])
    // prepareTarget resolves the bundle identifier from the pid; Finder is always present in a GUI session.
    guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.processIdentifier else { return }
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: nil, isEditable: true, isSecure: false, valueLength: 0, selectedRange: CFRange(location: 0, length: 0), bounds: nil, value: "", elementToken: "\(pid):field"))
    let target = RuntimeTarget()
    target.snapshot = TargetSnapshot(processIdentifier: pid, elementToken: "\(pid):field", replacementLocation: 0, replacementLength: 0, expectedValueDigest: SystemInsertionTarget.digest(""))
    let runtime = RecallRuntime(inspector: inspector, target: target, index: index, repository: vault.repository, permission: { true })
    runtime.start()
    // Two characters faster than the 50 ms commit window: the first commit must yield to the second,
    // not reset the session.
    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    // The keystrokes land in the destination field during the commit window.
    target.snapshot = TargetSnapshot(processIdentifier: pid, elementToken: "\(pid):field", replacementLocation: 2, replacementLength: 0, expectedValueDigest: SystemInsertionTarget.digest("da"))
    try await waitUntil { runtime.panelIsVisibleForTesting }
    #expect(runtime.panelIsVisibleForTesting)
    #expect(runtime.queryForTesting == "da")
    #expect(runtime.resultTitlesForTesting == ["Davood"])
    runtime.stopAndPurge()
}

@MainActor @Test func manualPanelSurvivesPermissionRefreshAndShortcutChords() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Alpha one", behavior: .savedText, plainContent: "one")], clipboardEvents: [])
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false })
    runtime.openManual(scope: .saved)
    try await waitUntil { runtime.panelIsVisibleForTesting }
    // The two-second permission refresh calls start(); with permission still missing it must not
    // tear down a manual panel the user deliberately opened.
    runtime.start()
    #expect(runtime.panelIsVisibleForTesting)
    // The opening hotkey chord itself reaches the event tap as .reset and must not dismiss either.
    #expect(!runtime.receive(.reset))
    #expect(runtime.panelIsVisibleForTesting)
    // Without an insertion target the panel takes keyboard focus so navigation works tap-free.
    #expect(runtime.panelAcceptsKeyboardForTesting)
    runtime.stopAndPurge()
    #expect(!runtime.panelIsVisibleForTesting)
}

@MainActor @Test func clicksInsideThePanelPassThroughWhileOutsideClicksDismiss() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Alpha one", behavior: .savedText, plainContent: "one")], clipboardEvents: [])
    let pointer = PointerBox()
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false }, pointer: { pointer.location })
    runtime.openManual(scope: .saved)
    try await waitUntil { runtime.panelIsVisibleForTesting }
    pointer.location = CGPoint(x: runtime.panelFrameForTesting.midX, y: runtime.panelFrameForTesting.midY)
    #expect(!runtime.receive(.pointerDown))
    #expect(runtime.panelIsVisibleForTesting)
    pointer.location = CGPoint(x: runtime.panelFrameForTesting.maxX + 200, y: runtime.panelFrameForTesting.maxY + 200)
    #expect(!runtime.receive(.pointerDown))
    #expect(!runtime.panelIsVisibleForTesting)
}

@MainActor @Test func arrowsAndReturnSelectFromTheManualPanel() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [
        SavedItem(title: "Alpha one", behavior: .savedText, plainContent: "alpha body", updatedAt: Date(timeIntervalSince1970: 90_000)),
        SavedItem(title: "Beta two", behavior: .savedText, plainContent: "beta body", updatedAt: Date(timeIntervalSince1970: 1)),
    ], clipboardEvents: [])
    let board = NSPasteboard(name: .init("koru-manual-select"))
    board.clearContents()
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false }, pasteboard: board)
    runtime.openManual(scope: .saved)
    try await waitUntil { runtime.resultTitlesForTesting.count == 2 }
    #expect(runtime.panelSelectedIDForTesting != nil)
    let first = runtime.panelSelectedIDForTesting
    #expect(runtime.receive(.navigation(1)))
    #expect(runtime.panelSelectedIDForTesting != first)
    #expect(runtime.receive(.confirm))
    // Without an insertion target, Return copies the selection to the pasteboard and closes the panel.
    try await waitUntil { !runtime.panelIsVisibleForTesting }
    #expect(!runtime.panelIsVisibleForTesting)
    #expect(board.string(forType: .string) == "beta body")
}

@MainActor @Test func keyboardFocusedPanelRoutesKeyEventsAsPanelCommands() {
    let panel = KoruPanel(contentRect: .init(x: 0, y: 0, width: 100, height: 100))
    var received: [TypedInputMessage] = []
    panel.onPanelCommand = { message in received.append(message); return true }
    func keyEvent(_ keyCode: UInt16, characters: String = "") -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }
    panel.sendEvent(keyEvent(125))
    panel.sendEvent(keyEvent(36, characters: "\r"))
    panel.sendEvent(keyEvent(53, characters: "\u{1B}"))
    panel.sendEvent(keyEvent(11, characters: "b"))
    #expect(received == [.navigation(1), .confirm, .dismiss, .character("b")])
}

@MainActor @Test func panelContentAcceptsFirstMouseSoRowsAreClickableWithoutKeyStatus() {
    #expect(FirstMouseHostingView(rootView: EmptyView()).acceptsFirstMouse(for: nil))
}

@Test func eventTapClassifiesPanelCommandsWithoutTreatingFocusAsInput() {
    func event(_ key: Int64, text: String? = nil) -> CGEvent {
        let source = CGEventSource(stateID: .privateState)!; let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: true)!
        if let text { var units = Array(text.utf16); event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units) }
        return event
    }
    #expect(TypedEventTapService.message(event(36)) == .confirm)
    #expect(TypedEventTapService.message(event(53)) == .dismiss)
    #expect(TypedEventTapService.message(event(51)) == .backspace)
    #expect(TypedEventTapService.message(event(125)) == .navigation(1))
    #expect(TypedEventTapService.message(event(0, text: "p")) == .character("p"))
}
