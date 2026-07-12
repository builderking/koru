import Foundation
import KoruDomain
@testable import KoruPlatform
import Testing

private func savedText(_ content: String, tags: [String], isPinned: Bool = false) -> SavedItem {
    SavedItem(
        title: "Legacy display title",
        behavior: .savedText,
        plainContent: content,
        tags: tags,
        isPinned: isPinned
    )
}

@Test func automaticTriggerRequiresTheCompleteAssignedTag() async {
    let index = InMemorySearchIndex()
    let item = savedText("Davood's reusable paragraph", tags: ["Dav"])
    await index.rebuild(savedItems: [item], clipboardEvents: [])

    let partial = "Hello da"
    #expect(await index.exactTriggerMatches(in: partial, caretUTF16: (partial as NSString).length).isEmpty)

    let complete = "Hello dav"
    let matches = await index.exactTriggerMatches(in: complete, caretUTF16: (complete as NSString).length)
    #expect(matches.map(\.result.source) == [.saved(item.id)])
    #expect(matches.first?.replacementRange == NSRange(location: 6, length: 3))
}

@Test func automaticTriggerMatchesCaseInsensitivelyAtTheCaretInsideExistingWriting() async {
    let index = InMemorySearchIndex()
    let item = savedText("Reusable response", tags: ["DaV"])
    await index.rebuild(savedItems: [item], clipboardEvents: [])

    let value = "👋 Existing paragraph DAV continues here."
    let caret = ("👋 Existing paragraph DAV" as NSString).length
    let matches = await index.exactTriggerMatches(in: value, caretUTF16: caret)

    #expect(matches.map(\.result.source) == [.saved(item.id)])
    #expect(matches.first?.trigger == "DaV")
    #expect(matches.first?.replacementRange == NSRange(location: caret - 3, length: 3))
}

@Test func automaticTriggerSupportsAnExactMultiwordTag() async {
    let index = InMemorySearchIndex()
    let item = savedText("Thanks for following up.", tags: ["client follow up"])
    await index.rebuild(savedItems: [item], clipboardEvents: [])

    let value = "Draft: client follow up"
    let matches = await index.exactTriggerMatches(in: value, caretUTF16: (value as NSString).length)

    #expect(matches.map(\.result.source) == [.saved(item.id)])
    #expect(matches.first?.replacementRange == NSRange(location: 7, length: 16))
}

@Test func automaticTriggerRequiresALeftWordBoundary() async {
    let index = InMemorySearchIndex()
    let item = savedText("Reusable response", tags: ["dav"])
    await index.rebuild(savedItems: [item], clipboardEvents: [])

    let embedded = "undav"
    #expect(await index.exactTriggerMatches(in: embedded, caretUTF16: (embedded as NSString).length).isEmpty)

    let punctuated = "Hello (dav"
    let matches = await index.exactTriggerMatches(in: punctuated, caretUTF16: (punctuated as NSString).length)
    #expect(matches.map(\.result.source) == [.saved(item.id)])
    #expect(matches.first?.replacementRange == NSRange(location: 7, length: 3))
}

@Test func automaticTriggerUsesOnlyTheLongestExactSuffix() async {
    let index = InMemorySearchIndex()
    let short = savedText("Short trigger item", tags: ["follow up"])
    let long = savedText("Long trigger item", tags: ["client follow up"])
    await index.rebuild(savedItems: [short, long], clipboardEvents: [])

    let value = "Please send client follow up"
    let matches = await index.exactTriggerMatches(in: value, caretUTF16: (value as NSString).length)

    #expect(matches.map(\.result.source) == [.saved(long.id)])
    #expect(matches.first?.trigger == "client follow up")
}

@Test func automaticTriggerReturnsEveryItemAssignedTheSameExactTag() async {
    let index = InMemorySearchIndex()
    let first = savedText("First reusable paragraph", tags: ["reply now"])
    let second = savedText("Second reusable paragraph", tags: ["Reply Now"])
    await index.rebuild(savedItems: [first, second], clipboardEvents: [])

    let value = "reply now"
    let matches = await index.exactTriggerMatches(in: value, caretUTF16: (value as NSString).length)

    #expect(Set(matches.map(\.result.source)) == Set([.saved(first.id), .saved(second.id)]))
    #expect(matches.allSatisfy { $0.replacementRange == NSRange(location: 0, length: 9) })
}

@Test func manualSearchFindsSavedTextByTagAndContentWithoutASeparateTitle() async {
    let index = InMemorySearchIndex()
    let tagged = savedText("Kind regards,\nDavood", tags: ["signature"])
    let content = savedText("The invoice deadline is Friday.", tags: ["billing note"])
    await index.rebuild(savedItems: [tagged, content], clipboardEvents: [])

    let tagResults = await index.search("sign", scope: .saved)
    let contentResults = await index.search("deadline", scope: .saved)

    #expect(tagResults.first?.source == .saved(tagged.id))
    #expect(tagResults.first?.title == "Kind regards,")
    #expect(contentResults.first?.source == .saved(content.id))
    #expect(contentResults.first?.reason == "Matched content")
}

@Test func deterministicSearchRanksTermsLearningPinnedAndResets() async {
    let index = InMemorySearchIndex()
    let exact = SavedItem(title: "Push to GitHub", behavior: .quickReplacement, plainContent: "git push", matchTerms: [.init(value: "pus")])
    let fuzzy = SavedItem(title: "Publish release", behavior: .savedText, plainContent: "release", isPinned: true)
    await index.rebuild(savedItems: [fuzzy, exact], clipboardEvents: [])
    let first = await index.search("pus", scope: .saved)
    #expect(first.first?.source == .saved(exact.id)); #expect(first == (await index.search("pus", scope: .saved)))
    await index.recordSelection(query: "pub", itemID: fuzzy.id, appBundleID: "test.app")
    #expect((await index.search("pub", scope: .saved, appBundleID: "test.app")).contains { $0.reason == "Previously selected" })
    await index.resetLearning()
    #expect(!(await index.search("pub", scope: .saved, appBundleID: "test.app")).contains { $0.reason == "Previously selected" })
    await index.purge(); #expect((await index.search("pus", scope: .saved)).isEmpty)
}

@Test func searchIsBoundedAndSeparatesClipboardScope() async {
    let index = InMemorySearchIndex(maximumDocuments: 500)
    let saved = (0..<700).map { SavedItem(title: "entry \($0)", behavior: .savedText, plainContent: "needle") }
    let event = ClipboardEvent(expiresAt: .now.addingTimeInterval(10), representations: [.init(contentType: .plainText, displayMetadata: "Clipboard text")])
    let payload = ClipboardPayload(event: event, searchableText: "needle clipboard", keyedContentDigest: Data())
    await index.rebuild(savedItems: saved, clipboardEvents: [payload])
    #expect((await index.search("needle", scope: .saved, limit: 100)).count == 50)
    #expect((await index.search("needle", scope: .clipboard)).first?.source == .clipboard(event.id))
}

@Test func emptyClipboardRecallIncludesImageRowsButStillFiltersUnsupportedNonTextRows() async {
    let index = InMemorySearchIndex()
    let textEvent = ClipboardEvent(expiresAt: .now.addingTimeInterval(10), representations: [.init(contentType: .plainText)])
    let imageEvent = ClipboardEvent(expiresAt: .now.addingTimeInterval(10), representations: [.init(contentType: .image)])
    let mixedEvent = ClipboardEvent(expiresAt: .now.addingTimeInterval(10), representations: [.init(contentType: .plainText), .init(contentType: .image)])
    let fileEvent = ClipboardEvent(expiresAt: .now.addingTimeInterval(10), representations: [.init(contentType: .fileReference)])
    await index.rebuild(savedItems: [], clipboardEvents: [
        .init(event: textEvent, searchableText: "insertable", keyedContentDigest: Data([1])),
        .init(event: imageEvent, searchableText: nil, keyedContentDigest: Data([2])),
        .init(event: mixedEvent, searchableText: "image caption", keyedContentDigest: Data([4])),
        .init(event: fileEvent, searchableText: nil, keyedContentDigest: Data([3])),
    ])

    let results = await index.search("", scope: .clipboard, includeAllWhenEmpty: true)
    #expect(Set(results.map(\.source)) == Set([.clipboard(textEvent.id), .clipboard(imageEvent.id), .clipboard(mixedEvent.id)]))
    #expect(results.first(where: { $0.source == .clipboard(imageEvent.id) })?.contentType == .image)
    #expect(results.first(where: { $0.source == .clipboard(mixedEvent.id) })?.contentType == .image)
}

@Test func retentionNeverTouchesPermanentSavedItemsAndOrdersBoundaries() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let saved = SavedItem(title: "permanent", behavior: .savedText, plainContent: "keep")
    try await vault.repository.save(saved)
    let now = Date(timeIntervalSince1970: 20_000)
    for offset in 0..<4 {
        let event = ClipboardEvent(capturedAt: now.addingTimeInterval(Double(-offset)), expiresAt: now.addingTimeInterval(100), representations: [.init(contentType: .plainText, byteSize: 1)])
        try await vault.repository.saveClipboard(.init(event: event, searchableText: "clip \(offset)", keyedContentDigest: Data([UInt8(offset)])))
    }
    var policy = RetentionPolicy(maximumAge: 1000, maximumEvents: 2, maximumAssetBytes: 10_000, maximumImageBytes: 100, clipboardHistoryEnabled: true)
    #expect(try await vault.repository.applyRetention(policy, now: now).count == 2)
    #expect(try await vault.repository.item(id: saved.id) != nil)
    policy.clipboardHistoryEnabled = false
    #expect(try await vault.repository.applyRetention(policy, now: now).count == 2)
    #expect(try await vault.repository.item(id: saved.id) != nil)
}

@Test func clipboardStorageAndRetentionAccountForOriginalAndThumbnailBytes() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let event = ClipboardEvent(
        expiresAt: .now.addingTimeInterval(1_000),
        representations: [.init(contentType: .image, thumbnailByteSize: 2_000, byteSize: 1_000)]
    )
    try await vault.repository.saveClipboard(.init(event: event, keyedContentDigest: Data([8])))
    #expect(try await vault.repository.storageSummary().encryptedBytes > 3_000)

    let policy = RetentionPolicy(maximumAge: 1_000, maximumEvents: 10, maximumAssetBytes: 2_500, maximumImageBytes: 1_000, clipboardHistoryEnabled: true)
    #expect(try await vault.repository.applyRetention(policy).map(\.rawValue) == [event.id.rawValue])
}

@Test func exclusionPoliciesFailClosedForUnknownAndIncludeSensitiveDefaults() async {
    let policy = ExclusionPolicy()
    #expect(!(await policy.mayObserve(nil)))
    #expect(!(await policy.maySaveClipboard(from: "com.1password.1password")))
    #expect(await policy.maySaveClipboard(from: "com.example.editor"))
}

@Test func queryLearningPersistsOnlyInsideEncryptedRecordsAndResetsIndependently() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let item = SavedItem(title: "Learned item", behavior: .savedText, plainContent: "body"); try await vault.repository.save(item)
    let index = InMemorySearchIndex(); await index.rebuild(savedItems: [item], clipboardEvents: [])
    let learning = QueryLearningService(repository: vault.repository, index: index)
    try await learning.recordExplicitSelection(query: "private-query-marker", itemID: item.id, appBundleID: "com.example.editor")
    #expect((await index.search("private-query-marker", scope: .saved, appBundleID: "com.example.editor")).first?.reason == "Previously selected")
    try await learning.reset()
    #expect(try await vault.repository.item(id: item.id) != nil)
    #expect(try await vault.repository.recallSignals().isEmpty)
    let db = try Data(contentsOf: vault.root.appendingPathComponent("vault.sqlite"))
    #expect(!db.contains(Data("private-query-marker".utf8)))
}
