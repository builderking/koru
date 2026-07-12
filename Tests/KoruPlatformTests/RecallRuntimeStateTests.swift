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
    func replace(range: NSRange, with text: String) -> Bool { guard allowsDirectReplacement else { return false }; replacement = (range, text); snapshot?.replacementLocation = range.location + text.utf16.count; snapshot?.replacementLength = 0; return true }
    func select(range: NSRange) -> Bool { snapshot?.replacementLocation = range.location; snapshot?.replacementLength = range.length; return true }
}

@Test func automaticTagsRequireThreeCharacters() { #expect(KoruPolicy.minimumTriggerLength == 3) }

@Test func explicitTypedInsertionRevalidatesDigestAndReplacesOnlyTheTagInExistingWriting() {
    let target = RuntimeTarget()
    let digest = SystemInsertionTarget.digest("Hello pus")
    target.snapshot = .init(processIdentifier: 4, elementToken: "field", replacementLocation: 9, replacementLength: 0, expectedValueDigest: digest)
    let expected = TargetSnapshot(processIdentifier: 4, elementToken: "field", replacementLocation: 6, replacementLength: 3, expectedValueDigest: digest)
    let transaction = InsertionTransaction(invocation: .initialTypedMatch, target: expected, requestedTier: .directAccessibility, explicitlyConfirmed: true)
    let board = NSPasteboard(name: .init("koru-runtime-prefix"))
    #expect(InsertionCoordinator(target: target, pasteboard: board).insert("Push to GitHub", transaction: transaction, capability: .full) == .inserted(.directAccessibility))
    #expect(target.replacement?.0 == NSRange(location: 6, length: 3))
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
    #expect(results.map(\.title) == ["two", "one"])
    #expect(await index.search("", scope: .saved).isEmpty)
}

private struct NoFocusInspector: AccessibilityInspecting {
    func focusedTarget() -> Result<AXTargetSnapshot, AXInspectionError> { .failure(.noFocusedElement) }
}

private actor FakeClipboardContentResolver: ClipboardContentResolving {
    let content: ClipboardImageContent
    private(set) var thumbnailCalls = 0
    private(set) var imageCalls = 0
    init(content: ClipboardImageContent) { self.content = content }
    func thumbnail(eventID: ClipboardEventID, maximumBytes: Int) -> Data? { thumbnailCalls += 1; return content.thumbnailData.count <= maximumBytes ? content.thumbnailData : nil }
    func image(eventID: ClipboardEventID) -> ClipboardImageContent? { imageCalls += 1; return content }
}

private func onePixelClipboardImage() -> ClipboardImageContent {
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    return .init(originalData: png, thumbnailData: png, format: .png)
}

@MainActor private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
}

@MainActor @Test func shortcutOpenedPanelListsHydratedSavedItemsWithEmptyQuery() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    let newer = SavedItem(title: "Legacy Alpha", behavior: .savedText, plainContent: "Alpha one", updatedAt: Date(timeIntervalSince1970: 90_000))
    let older = SavedItem(title: "Legacy Beta", behavior: .savedText, plainContent: "Beta two", updatedAt: Date(timeIntervalSince1970: 1))
    await index.rebuild(savedItems: [newer, older], clipboardEvents: [])
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false })
    runtime.openManual(scope: .saved)
    try await waitUntil { runtime.resultTitlesForTesting.count == 2 }
    #expect(runtime.panelIsVisibleForTesting)
    #expect(runtime.resultTitlesForTesting == ["Alpha one", "Beta two"])
}

@MainActor @Test func clipboardPanelHydratesAndCachesARealImageThumbnailThenCopiesTheOriginal() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let event = ClipboardEvent(expiresAt: .now.addingTimeInterval(100), representations: [.init(contentType: .image)])
    let payload = ClipboardPayload(event: event, keyedContentDigest: Data([4]))
    let index = InMemorySearchIndex(); await index.rebuild(savedItems: [], clipboardEvents: [payload])
    let image = onePixelClipboardImage(); let resolver = FakeClipboardContentResolver(content: image)
    let board = NSPasteboard(name: .init("koru-manual-image")); board.clearContents()
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false }, pasteboard: board, clipboardContentResolver: resolver)

    runtime.openManual(scope: .clipboard)
    try await waitUntil { runtime.panelRowsForTesting.first?.thumbnailData != nil }
    #expect(runtime.panelRowsForTesting.first?.contentType == .image)
    #expect(runtime.panelRowsForTesting.first?.thumbnailData == image.thumbnailData)
    #expect(runtime.panelFrameForTesting.height < RecallPanelLayout.maximumHeight)

    #expect(runtime.receive(.character("x")))
    try await waitUntil { runtime.panelRowsForTesting.isEmpty }
    #expect(runtime.receive(.backspace))
    try await waitUntil { runtime.panelRowsForTesting.first?.thumbnailData != nil }
    #expect(await resolver.thumbnailCalls == 1)

    #expect(runtime.receive(.confirm))
    try await waitUntil { board.data(forType: .png) == image.originalData }
    #expect(await resolver.imageCalls == 1)
    #expect(board.string(forType: .string) == nil)
    #expect(!runtime.panelIsVisibleForTesting)
}

@MainActor @Test func automaticClipboardImageSelectionUsesTheGuardedPreparedPasteSequence() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let event = ClipboardEvent(expiresAt: .now.addingTimeInterval(100), representations: [.init(contentType: .image)])
    let index = InMemorySearchIndex(); await index.rebuild(savedItems: [], clipboardEvents: [.init(event: event, keyedContentDigest: Data([5]))])
    let image = onePixelClipboardImage(); let resolver = FakeClipboardContentResolver(content: image)
    let pid: pid_t = 5252; let token = "\(pid):image-field"
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: nil, isEditable: true, isSecure: false, valueLength: 3, selectedRange: CFRange(location: 3, length: 0), bounds: nil, value: "clp", elementToken: token))
    let board = NSPasteboard(name: .init("koru-automatic-image")); board.clearContents()
    let synthetic = SyntheticRequestBox()
    let runtime = RecallRuntime(inspector: inspector, target: RuntimeTarget(), index: index, repository: vault.repository, permission: { true }, pasteboard: board, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { true }, clipboardContentResolver: resolver, syntheticReplace: { text, request in synthetic.text = text; synthetic.request = request; return .inserted })
    runtime.start()

    #expect(!runtime.receive(.character("c")))
    #expect(!runtime.receive(.character("l")))
    #expect(!runtime.receive(.character("p")))
    try await waitUntil { runtime.panelRowsForTesting.first?.thumbnailData != nil }
    #expect(runtime.receive(.confirm))
    try await waitUntil { synthetic.request != nil }
    #expect(synthetic.text == "")
    #expect(synthetic.request?.expectedElementToken == token)
    #expect(synthetic.request?.deletionCharacterCount == 3)
    #expect(board.data(forType: .png) == image.originalData)
    runtime.stopAndPurge()
}

@MainActor @Test func typedCharactersFilterTheShortcutOpenedPanelAndBackspaceRestores() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [
        SavedItem(title: "Legacy Alpha", behavior: .savedText, plainContent: "Alpha one", updatedAt: Date(timeIntervalSince1970: 90_000)),
        SavedItem(title: "Legacy Beta", behavior: .savedText, plainContent: "Beta two", updatedAt: Date(timeIntervalSince1970: 1)),
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

@MainActor @Test func secureFieldMatchUsesTheSameContextGuardedKeyboardReplacement() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "Davood signature", tags: ["dav"])], clipboardEvents: [])
    guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.processIdentifier else { return }
    // Secure status is metadata for recall. If macOS delivers the typed events and exposes a stable
    // focused element, Koru performs the same guarded keyboard replacement as every other field.
    let elementToken = "\(pid):secure-composer"
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: "AXSecureTextField", isEditable: true, isSecure: true, valueLength: 10, selectedRange: CFRange(location: 9, length: 0), bounds: nil, value: "Hello dav\n", elementToken: elementToken))
    let target = RuntimeTarget()
    target.snapshot = TargetSnapshot(processIdentifier: pid, elementToken: elementToken, replacementLocation: 9, replacementLength: 0, expectedValueDigest: SystemInsertionTarget.digest("Hello dav\n"))
    let box = SyntheticRequestBox()
    let runtime = RecallRuntime(inspector: inspector, target: target, index: index, repository: vault.repository, permission: { true }, frontmostProcessIdentifier: { pid }, syntheticReplace: { _, request in box.request = request; return .inserted })
    runtime.start()
    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    #expect(!runtime.receive(.character("v")))
    try await waitUntil { runtime.panelIsVisibleForTesting }
    #expect(runtime.panelIsVisibleForTesting)
    #expect(runtime.queryForTesting == "dav")
    #expect(runtime.resultTitlesForTesting == ["Davood signature"])
    #expect(runtime.receive(.confirm))
    try await waitUntil { box.request != nil }
    #expect(box.request?.expectedElementToken == elementToken)
    #expect(box.request?.deletionCharacterCount == 3)
    #expect(target.replacement == nil)
    runtime.stopAndPurge()
}

private final class SyntheticRequestBox { var request: SyntheticReplacementRequest?; var text: String? }

@MainActor @Test func unresolvedFieldUsesRollingBufferButSelectionCopiesWithoutDeletingTheTag() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "signature", tags: ["dav"])], clipboardEvents: [])
    let pid: pid_t = 4242
    let box = SyntheticRequestBox()
    let board = NSPasteboard(name: .init("koru-unresolved-copy-only")); board.clearContents()
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false }, pasteboard: board, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { true }, syntheticReplace: { _, request in box.request = request; return .inserted })
    runtime.start()
    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(!runtime.panelIsVisibleForTesting)
    #expect(!runtime.receive(.character("v")))
    try await waitUntil { runtime.panelIsVisibleForTesting }
    #expect(runtime.panelIsVisibleForTesting)
    #expect(runtime.queryForTesting == "dav")
    #expect(runtime.resultTitlesForTesting == ["signature"])
    #expect(runtime.panelNoticeForTesting?.contains("leave the typed tag unchanged") == true)
    #expect(runtime.receive(.confirm))
    try await waitUntil { board.string(forType: .string) == "signature" }
    #expect(box.request == nil)
    #expect(board.string(forType: KoruPasteboardOrigin.type) == KoruPasteboardOrigin.value)
    runtime.stopAndPurge()
}

@MainActor @Test func staleMaskedAccessibilityValueFallsBackToRollingInputAndRetainsFocusedElementIdentity() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "signature", tags: ["dav"])], clipboardEvents: [])
    let pid: pid_t = 4243
    let elementToken = "\(pid):masked-composer"
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: nil, isEditable: true, isSecure: false, valueLength: 3, selectedRange: CFRange(location: 3, length: 0), bounds: nil, value: "•••", elementToken: elementToken))
    let box = SyntheticRequestBox()
    let runtime = RecallRuntime(inspector: inspector, target: RuntimeTarget(), index: index, repository: vault.repository, permission: { true }, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { true }, syntheticReplace: { _, request in box.request = request; return .inserted })
    runtime.start()

    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    #expect(!runtime.receive(.character("v")))
    try await waitUntil { runtime.panelIsVisibleForTesting }

    #expect(runtime.queryForTesting == "dav")
    #expect(runtime.resultTitlesForTesting == ["signature"])
    #expect(runtime.receive(.confirm))
    try await waitUntil { box.request != nil }
    #expect(box.request?.expectedGeneration != nil)
    #expect(box.request?.expectedElementToken == elementToken)
    runtime.stopAndPurge()
}

@MainActor @Test func returnAndEscapeWithoutAVisiblePanelResetTheAutomaticRollingSuffix() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "signature", tags: ["dav"])], clipboardEvents: [])
    let pid: pid_t = 4244
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false }, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { true })
    runtime.start()

    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(!runtime.panelIsVisibleForTesting)
    #expect(!runtime.receive(.confirm))
    #expect(!runtime.receive(.character("v")))
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(!runtime.panelIsVisibleForTesting)

    #expect(!runtime.receive(.reset))
    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    #expect(!runtime.receive(.dismiss))
    #expect(!runtime.receive(.character("v")))
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(!runtime.panelIsVisibleForTesting)
    runtime.stopAndPurge()
}

@MainActor @Test func nonASCIICapableInputSourceDisablesOnlyTheRollingFallback() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "signature", tags: ["dav"])], clipboardEvents: [])
    let pid: pid_t = 4245
    let runtime = RecallRuntime(inspector: NoFocusInspector(), target: RuntimeTarget(), index: index, repository: vault.repository, permission: { false }, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { false })
    runtime.start()

    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    #expect(!runtime.receive(.character("v")))
    try await Task.sleep(nanoseconds: 150_000_000)
    #expect(!runtime.panelIsVisibleForTesting)
    #expect(runtime.queryForTesting.isEmpty)
    runtime.stopAndPurge()

    let token = "\(pid):committed-field"
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: nil, isEditable: true, isSecure: false, valueLength: 3, selectedRange: CFRange(location: 3, length: 0), bounds: nil, value: "dav", elementToken: token))
    let target = RuntimeTarget()
    target.snapshot = .init(processIdentifier: pid, elementToken: token, replacementLocation: 3, replacementLength: 0, expectedValueDigest: SystemInsertionTarget.digest("dav"))
    let accessibilityRuntime = RecallRuntime(inspector: inspector, target: target, index: index, repository: vault.repository, permission: { true }, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { false })
    accessibilityRuntime.start()
    #expect(!accessibilityRuntime.receive(.character("d")))
    #expect(!accessibilityRuntime.receive(.character("a")))
    #expect(!accessibilityRuntime.receive(.character("v")))
    try await waitUntil { accessibilityRuntime.panelIsVisibleForTesting }
    #expect(accessibilityRuntime.queryForTesting == "dav")
    accessibilityRuntime.stopAndPurge()
}

@MainActor @Test func accessibilityInsertionRequiresTheInspectorAndTargetToNameTheSameElement() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "signature", tags: ["dav"])], clipboardEvents: [])
    let pid: pid_t = 4246
    let inspectorToken = "\(pid):field-a"
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: nil, isEditable: true, isSecure: false, valueLength: 3, selectedRange: CFRange(location: 3, length: 0), bounds: nil, value: "dav", elementToken: inspectorToken))
    let target = RuntimeTarget()
    target.snapshot = .init(processIdentifier: pid, elementToken: "\(pid):field-b", replacementLocation: 3, replacementLength: 0, expectedValueDigest: SystemInsertionTarget.digest("dav"))
    let box = SyntheticRequestBox()
    let runtime = RecallRuntime(inspector: inspector, target: target, index: index, repository: vault.repository, permission: { true }, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { true }, syntheticReplace: { _, request in box.request = request; return .inserted })
    runtime.start()

    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    #expect(!runtime.receive(.character("v")))
    try await waitUntil { runtime.panelIsVisibleForTesting }
    #expect(runtime.receive(.confirm))
    try await waitUntil { box.request != nil }
    #expect(target.replacement == nil)
    #expect(box.request?.expectedElementToken == inspectorToken)
    runtime.stopAndPurge()
}

@MainActor @Test func syntheticFocusIdentityLossFallsBackToMarkedCopyWithoutTargetMutation() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let index = InMemorySearchIndex()
    await index.rebuild(savedItems: [SavedItem(title: "Legacy", behavior: .savedText, plainContent: "signature", tags: ["dav"])], clipboardEvents: [])
    let pid: pid_t = 4247
    let inspector = ScriptedFocusInspector(snapshot: .init(processIdentifier: pid, role: "AXTextArea", subrole: nil, isEditable: true, isSecure: false, valueLength: 3, selectedRange: CFRange(location: 3, length: 0), bounds: nil, value: "dav", elementToken: "\(pid):field-a"))
    let target = RuntimeTarget()
    let board = NSPasteboard(name: .init("koru-synthetic-context-copy")); board.clearContents()
    let runtime = RecallRuntime(inspector: inspector, target: target, index: index, repository: vault.repository, permission: { true }, pasteboard: board, frontmostProcessIdentifier: { pid }, allowsRollingFallback: { true })
    runtime.start()

    #expect(!runtime.receive(.character("d")))
    #expect(!runtime.receive(.character("a")))
    #expect(!runtime.receive(.character("v")))
    try await waitUntil { runtime.panelIsVisibleForTesting }
    inspector.snapshot.elementToken = "\(pid):field-b"
    #expect(runtime.receive(.confirm))
    try await waitUntil { board.string(forType: .string) == "signature" }
    #expect(target.replacement == nil)
    #expect(board.string(forType: KoruPasteboardOrigin.type) == KoruPasteboardOrigin.value)
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
    #expect(TypedEventTapService.message(event(49, text: " ")) == .character(" "))
}
