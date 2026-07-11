import AppKit
import KoruDomain
import Testing
@testable import KoruPlatform

private final class FakeIntegration: RuntimeIntegration { var starts = 0; var purges = 0; func start() { starts += 1 }; func stopAndPurge() { purges += 1 } }
private struct FakePermissions: PermissionChecking {
    var trusted = false
    func accessibility(prompt: Bool) -> Bool { trusted }; func inputListening(request: Bool) -> Bool { trusted }; func eventPosting(request: Bool) -> Bool { trusted }
    func pasteboard() -> PermissionState { .unavailable }; func loginItem() -> PermissionState { .denied }
}
private final class Receiver: SaveConfirmationReceiving { var input: SaveConfirmationInput?; func receive(_ input: SaveConfirmationInput) { self.input = input } }
private struct Reader: SelectedTextReading { var result: Result<String, AXInspectionError>; func selectedText() -> Result<String, AXInspectionError> { result } }
private final class FakeTarget: InsertionTargetAccessing, @unchecked Sendable {
    var snapshot: TargetSnapshot?; var replaced = false; var selected = false
    func currentSnapshot() -> TargetSnapshot? { snapshot }; func replace(range: NSRange, with text: String) -> Bool { replaced = true; return true }; func select(range: NSRange) -> Bool { selected = true; return true }
}

@Test func permissionRevocationIsExplicit() {
    let granted = PermissionCoordinator(checker: FakePermissions(trusted: true)); #expect(granted.refresh().accessibility == .granted)
    let denied = PermissionCoordinator(checker: FakePermissions()); #expect(denied.refresh().accessibility == .denied)
}

@Test func lifecyclePurgesEveryIntegrationWhenPausedOrLocked() {
    let integration = FakeIntegration(); let lifecycle = IntegrationLifecycle(integrations: [integration]); lifecycle.transition(.paused); lifecycle.transition(.locked)
    #expect(integration.purges == 2); #expect(integration.starts == 0)
}

@Test(arguments: [
    SecurityContext(bundleIdentifier: nil, role: "AXTextField", subrole: nil, protectedContent: false, editable: true),
    SecurityContext(bundleIdentifier: "com.apple.keychainaccess", role: "AXTextField", subrole: nil, protectedContent: false, editable: true),
    SecurityContext(bundleIdentifier: "example", role: "AXTextField", subrole: "AXSecureTextField", protectedContent: false, editable: true),
    SecurityContext(bundleIdentifier: "example", role: nil, subrole: nil, protectedContent: nil, editable: nil),
]) func classifierFailsClosed(context: SecurityContext) { guard case .blocked = SecurityContextClassifier().classify(context) else { Issue.record("unsafe context was allowed"); return } }

@Test func placementClampsAndLabelsFallback() {
    let placer = CaretPanelPlacer(); let frame = CGRect(x: 0, y: 0, width: 1000, height: 700)
    let placed = placer.place(panelSize: .init(width: 300, height: 180), caretAX: .init(x: 990, y: 690, width: 1, height: 18), visibleFrame: frame)
    #expect(placed.anchor == .caret); #expect(placed.origin.x <= 700); #expect(placed.origin.y >= 0)
    #expect(placer.place(panelSize: .init(width: 300, height: 180), caretAX: nil, visibleFrame: frame).anchor == .fallback)
}

@Test func resultIdentitySurvivesLiveUpdates() {
    var navigator = ResultNavigator(); navigator.update([.init(id: "a", title: "A", preview: ""), .init(id: "b", title: "B", preview: "")]); navigator.move(1); navigator.update([.init(id: "b", title: "B2", preview: ""), .init(id: "c", title: "C", preview: "")]); #expect(navigator.selectedID == "b")
}

@Test func selectionIconRequiresExactFullSelectionAndBounds() {
    let policy = SelectionIconPolicy(); #expect(policy.shouldShow(.init(selectedRange: .init(location: 0, length: 5), valueUTF16Length: 5, bounds: .init(x: 1, y: 1, width: 10, height: 10), contextAllowed: true, notificationsSupported: true)))
    #expect(!policy.shouldShow(.init(selectedRange: .init(location: 1, length: 4), valueUTF16Length: 5, bounds: .init(x: 1, y: 1, width: 10, height: 10), contextAllowed: true, notificationsSupported: true)))
}

@MainActor @Test func serviceUsesItsPasteboardWithoutWritingGeneralClipboard() {
    let receiver = Receiver(); let board = NSPasteboard(name: .init("koru-test-service")); board.clearContents(); board.setString("selected", forType: .string)
    let generalBefore = NSPasteboard.general.changeCount; #expect(SelectionServiceProcessor(receiver: receiver).process(board) == nil); #expect(receiver.input?.plainText == "selected"); #expect(NSPasteboard.general.changeCount == generalBefore)
}

@MainActor @Test func shortcutNeverSynthesizesCopyWhenSelectionUnavailable() {
    let receiver = Receiver(); let shortcut = SaveSelectionShortcut(reader: Reader(result: .failure(.unsupported)), receiver: receiver)
    #expect(shortcut.invoke(context: .allowed(.full)) == .useService); #expect(receiver.input == nil)
}

@Test func insertionRevalidatesImmediatelyAndRunsOnlyOnce() {
    let target = TargetSnapshot(processIdentifier: 7, elementToken: "field", replacementLocation: 0, replacementLength: 3); let access = FakeTarget(); access.snapshot = target
    var transaction = InsertionTransaction(invocation: .initialTypedMatch, target: target, requestedTier: .directAccessibility, explicitlyConfirmed: true)
    let board = NSPasteboard(name: .init("koru-test-insert")); let coordinator = InsertionCoordinator(target: access, pasteboard: board, postPaste: { false })
    #expect(coordinator.insert("hello", transaction: transaction, capability: .full) == .inserted(.directAccessibility)); #expect(access.replaced)
    transaction.target.elementToken = "changed"; #expect(coordinator.insert("unsafe", transaction: transaction, capability: .full) == .cancelledTargetChanged)
}

@Test func generatedSessionsNeverOpenFromEstablishedWriting() {
    for length in 1...1_000 { var session = FreshInputSession(); let value = String(repeating: "x", count: length); session.handle(.focus(value: value, selectionLocation: length, selectionLength: 0, editable: true, secure: false, excluded: false)); session.handle(.committedCharacter("p", hasQualifyingMatch: true)); guard case .ineligibleUntilFocusChanges = session.state else { Issue.record("opened at length \(length)"); return } }
}

@Test func prefixValidationRejectsExternalMutation() {
    var session = FreshInputSession(); session.handle(.focus(value: "", selectionLocation: 0, selectionLength: 0, editable: true, secure: false, excluded: false)); session.handle(.committedCharacter("p", hasQualifyingMatch: false)); session.handle(.validate(value: "px", caretLocation: 2, selectionLength: 0)); #expect(session.state == .ineligibleUntilFocusChanges)
}
