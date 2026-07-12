import AppKit
import Foundation
import KoruDomain
@testable import KoruPlatform
import Testing

final class FakePasteboard: PasteboardSnapshotSource, @unchecked Sendable {
    var count = 0; var state: PasteboardAccessState = .available; var groups: [[MaterializedPasteboardItem]] = []; var koruOriginated = false
    func changeCount() -> Int { count }; func accessState() -> PasteboardAccessState { state }
    func isKoruOriginatedChange() -> Bool { koruOriginated }
    func materialize(limits: PasteboardLimits) throws -> [[MaterializedPasteboardItem]] { groups }
}

@Test func generalPasteboardSourceDetectsOnlyTheExactKoruOriginMarker() {
    let pasteboard = NSPasteboard(name: .init("koru-origin-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }
    let source = GeneralPasteboardSource(pasteboard: pasteboard)

    pasteboard.prepareForNewContents(with: .currentHostOnly)
    pasteboard.setString("ordinary copy", forType: .string)
    #expect(!source.isKoruOriginatedChange())

    #expect(KoruPasteboardOrigin.write("Koru copy", to: pasteboard))
    #expect(source.isKoruOriginatedChange())

    pasteboard.prepareForNewContents(with: .currentHostOnly)
    pasteboard.setString("another-app", forType: KoruPasteboardOrigin.type)
    pasteboard.setString("not Koru", forType: .string)
    #expect(!source.isKoruOriginatedChange())
}

@Test func clipboardImageResolverDecryptsABoundedThumbnailAndPreservesOriginalPasteboardBytes() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    let asset = try await vault.assets.store(png)
    let event = ClipboardEvent(
        expiresAt: .now.addingTimeInterval(100),
        representations: [.init(contentType: .image, encryptedPayloadReference: asset.opaqueName, byteSize: png.count)]
    )
    try await vault.repository.saveClipboard(.init(event: event, keyedContentDigest: Data([9])))

    let resolver = ClipboardContentResolver(repository: vault.repository, assets: vault.assets, maximumImageBytes: 1024, thumbnailPixels: 64)
    let resolved = try #require(try await resolver.image(eventID: event.id))
    #expect(resolved.originalData == png)
    #expect(resolved.format == .png)
    #expect(NSImage(data: resolved.thumbnailData) != nil)

    let pasteboard = NSPasteboard(name: .init("koru-image-resolver-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }
    #expect(KoruPasteboardOrigin.writeImage(resolved, to: pasteboard))
    #expect(pasteboard.data(forType: .png) == png)
    #expect(pasteboard.string(forType: KoruPasteboardOrigin.type) == KoruPasteboardOrigin.value)
}

@Test func capturedImagesPersistASeparateSmallThumbnailForTheClipboardPanel() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    let fake = FakePasteboard(); var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: ExclusionPolicy(), policy: policy)
    await monitor.setEnabled(true)
    fake.groups = [[.init(contentType: .image, value: .data(png))]]
    fake.count = 1

    let eventID = try #require(try await monitor.poll(frontmostBundleID: "com.example.editor"))
    let payload = try #require(try await vault.repository.clipboardEvents().first(where: { $0.event.id == eventID }))
    let representation = try #require(payload.event.representations.first)
    #expect(representation.encryptedPayloadReference != nil)
    #expect(representation.encryptedThumbnailReference != nil)
    #expect((representation.thumbnailByteSize ?? 0) > 0)

    let resolver = ClipboardContentResolver(repository: vault.repository, assets: vault.assets)
    let thumbnail = try #require(try await resolver.thumbnail(eventID: eventID))
    #expect(NSImage(data: thumbnail) != nil)
}

@Test func pasteboardMonitorSkipsKoruMarkedWritesWithoutPersistingThem() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let fake = FakePasteboard(); var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: ExclusionPolicy(), policy: policy)
    await monitor.setEnabled(true)
    fake.groups = [[.init(contentType: .plainText, value: .data(Data("Koru copy".utf8)))]]
    fake.koruOriginated = true; fake.count = 1

    #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") == nil)
    #expect(try await vault.repository.clipboardEvents().isEmpty)

    fake.koruOriginated = false; fake.count = 2
    #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") != nil)
    #expect(try await vault.repository.clipboardEvents().count == 1)
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

@Test func retentionInitializationEnablesCaptureAndSurvivesLockUnlock() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let fake = FakePasteboard(); let exclusions = ExclusionPolicy(); let search = InMemorySearchIndex()
    var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    // The app constructs the monitor before stored settings are known; capture stays opted out until
    // the effective retention policy is pushed at vault open (the launch initialization path).
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: exclusions)
    let controller = ClipboardHistoryController(monitor: monitor, repository: vault.repository, search: search, exclusions: exclusions)
    fake.groups = [[.init(contentType: .plainText, value: .data(Data("first copy".utf8)))]]
    fake.count = 1
    await #expect(throws: PasteboardDecodeError.disabled) { try await monitor.poll(frontmostBundleID: "com.example.editor") }
    try await controller.updateRetention(policy)
    #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") != nil)
    // Sleep or lock suspends the monitor; changes made while locked are intentionally skipped.
    await monitor.suspend()
    fake.groups = [[.init(contentType: .plainText, value: .data(Data("while locked".utf8)))]]
    fake.count = 2
    await #expect(throws: PasteboardDecodeError.disabled) { try await monitor.poll(frontmostBundleID: "com.example.editor") }
    // Wake re-runs the same initialization and resumes; the next copy must be captured again.
    try await controller.updateRetention(policy)
    await monitor.resume()
    fake.groups = [[.init(contentType: .plainText, value: .data(Data("after wake".utf8)))]]
    fake.count = 3
    #expect(try await monitor.poll(frontmostBundleID: "com.example.editor") != nil)
    let texts = try await vault.repository.clipboardEvents().compactMap(\.searchableText).sorted()
    #expect(texts == ["after wake", "first copy"])
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

@Test func clpCanReplaceItsExactSpanAnywhereAndManualRecallNeedsNoSpan() async {
    let search = InMemorySearchIndex(); let service = ClipboardRecallService(search: search)
    let typed = await service.typedCLP(commandSpan: 12..<15)
    let focused = await service.focusSearch("more", session: typed)
    #expect(focused.originalCommandSpan == 12..<15)
    #expect(await service.manualHotKey().originalCommandSpan == nil)
}

@Test func clipboardControlsClearOnlyHistoryAndSaveCreatesSeparatePermanentItem() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let fake = FakePasteboard(); let exclusions = ExclusionPolicy(); let search = InMemorySearchIndex(); var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let monitor = PasteboardMonitor(source: fake, repository: vault.repository, assets: vault.assets, keys: vault.keys, exclusions: exclusions, policy: policy)
    let controller = ClipboardHistoryController(monitor: monitor, repository: vault.repository, search: search, exclusions: exclusions, policy: policy)
    let event = ClipboardEvent(expiresAt: .now.addingTimeInterval(100), representations: [.init(contentType: .plainText)])
    try await vault.repository.saveClipboard(.init(event: event, searchableText: "save me", keyedContentDigest: Data([1])))
    await #expect(throws: ProductValidationError.emptyTags) {
        try await controller.saveToLibrary(eventID: event.id, tags: [])
    }
    await #expect(throws: ProductValidationError.triggerTagTooShort) {
        try await controller.saveToLibrary(eventID: event.id, tags: ["no"])
    }
    await #expect(throws: ProductValidationError.reservedMatchTerm) {
        try await controller.saveToLibrary(eventID: event.id, tags: ["clp"])
    }
    await #expect(throws: ProductValidationError.duplicateMatchTerm) {
        try await controller.saveToLibrary(eventID: event.id, tags: ["saved clip", "SAVED CLIP"])
    }
    #expect(try await vault.repository.savedItems(states: [.active]).isEmpty)
    let saved = try await controller.saveToLibrary(eventID: event.id, tags: ["saved clip"])
    #expect(saved.title == "save me")
    #expect(saved.behavior == .savedText)
    #expect(saved.tags == ["saved clip"])
    #expect(saved.matchTerms == [.init(value: "saved clip", isPreferredInitialTerm: true, isExactTrigger: true)])
    #expect(saved.templateFields.isEmpty)
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
