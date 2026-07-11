import Foundation
import KoruDomain
@testable import KoruPlatform
import Testing

final class FakePasteboard: PasteboardSnapshotSource, @unchecked Sendable {
    var count = 0; var state: PasteboardAccessState = .available; var groups: [[MaterializedPasteboardItem]] = []
    func changeCount() -> Int { count }; func accessState() -> PasteboardAccessState { state }
    func materialize(limits: PasteboardLimits) throws -> [[MaterializedPasteboardItem]] { groups }
}

@Test func pasteboardMonitorRequiresOptInGroupsMixedTypesAndDeduplicates() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let fake = FakePasteboard(); let exclusions = ExclusionPolicy(); var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: exclusions, policy: policy)
    fake.groups = [[.init(contentType: .plainText, value: .data(Data("hello".utf8))), .init(contentType: .fileReference, value: .reference("file:///tmp/reference"), displayMetadata: "reference")]]
    await #expect(throws: PasteboardDecodeError.disabled) { try await monitor.poll(frontmostBundleID: "com.example.editor") }
    await monitor.setEnabled(true); fake.count = 1
    #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") != nil)
    let events = try await vault.repository.clipboardEvents(); #expect(events.count == 1); #expect(events[0].event.representations.count == 2)
    fake.count = 2; #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") == nil)
    fake.count = 3; await monitor.suppressKoruOriginatedChange(3); #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") == nil)
}

@Test func pasteboardDeniedExcludedAndOversizedFailWithoutPersistence() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let fake = FakePasteboard(); var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: ExclusionPolicy(), policy: policy)
    await monitor.setEnabled(true); fake.state = .denied; fake.count = 1
    await #expect(throws: PasteboardDecodeError.denied) { try await monitor.poll(frontmostBundleID: "com.example.editor") }
    fake.state = .available; fake.count = 2
    await #expect(throws: PasteboardDecodeError.excluded) { try await monitor.poll(frontmostBundleID: "com.1password.1password") }
    #expect(try await vault.repository.clipboardEvents().isEmpty)
}

@Test func clpRequiresFreshStartButManualRecallIsPermissionIndependent() async throws {
    let search = InMemorySearchIndex(); let service = ClipboardRecallService(search: search)
    await #expect(throws: ClipboardRecallError.ineligibleTypedInvocation) { try await service.typedCLP(verifiedFreshStart: false, commandSpan: 0..<3) }
    let typed = try await service.typedCLP(verifiedFreshStart: true, commandSpan: 0..<3)
    let focused = await service.focusSearch("more", session: typed)
    #expect(focused.originalCommandSpan == 0..<3)
    #expect(await service.manualHotKey().originalCommandSpan == nil)
}

@Test func clipboardControlsClearOnlyHistoryAndSaveCreatesSeparatePermanentItem() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let fake = FakePasteboard(); let exclusions = ExclusionPolicy(); let search = InMemorySearchIndex(); var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: exclusions, policy: policy)
    let controller = ClipboardHistoryController(monitor: monitor, repository: vault.repository, search: search, exclusions: exclusions, policy: policy)
    let event = ClipboardEvent(expiresAt: .now.addingTimeInterval(100), representations: [.init(contentType: .plainText)])
    try await vault.repository.saveClipboard(.init(event: event, searchableText: "save me", keyedContentDigest: Data([1])))
    let saved = try await controller.saveToLibrary(eventID: event.id, title: "Saved separately")
    try await controller.clearHistory()
    #expect(try await vault.repository.clipboardEvents().isEmpty)
    #expect(try await vault.repository.item(id: saved.id) != nil)
    #expect(try await controller.summary().retainedCount == 0)
}

@Test func concurrentClipboardWritesRemainConsistentUnderRetention() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let now = Date()
    await withTaskGroup(of: Void.self) { group in
        for value in 0..<40 { group.addTask {
            let event = ClipboardEvent(capturedAt: now.addingTimeInterval(Double(value)), expiresAt: now.addingTimeInterval(1_000), representations: [.init(contentType: .plainText)])
            try? await vault.repository.saveClipboard(.init(event: event, searchableText: "event \(value)", keyedContentDigest: Data([UInt8(value)])))
        } }
    }
    let policy = RetentionPolicy(maximumAge: 1_000, maximumEvents: 10, maximumAssetBytes: 10_000_000, maximumImageBytes: 1_000, clipboardHistoryEnabled: true)
    _ = try await vault.repository.applyRetention(policy, now: now)
    #expect(try await vault.repository.clipboardEvents().count == 10)
    #expect(try await vault.repository.integrityCheck())
}
