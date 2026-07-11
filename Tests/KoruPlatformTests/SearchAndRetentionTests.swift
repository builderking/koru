import Foundation
import KoruDomain
@testable import KoruPlatform
import Testing

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
