import Foundation
import KoruDomain

public enum SearchScope: Sendable { case saved; case clipboard }
public struct SearchResult: Hashable, Sendable {
    public enum Source: Hashable, Sendable { case saved(SavedItemID); case clipboard(ClipboardEventID) }
    public let source: Source
    public let score: Int
    public let reason: String
    public let title: String
    public let preview: String?
    public let contentType: ContentType
}

public actor InMemorySearchIndex {
    private struct SavedDocument: Sendable { let item: SavedItem; let normalizedTitle: String; let terms: [String]; let bodyTokens: Set<String>; let tagTokens: Set<String> }
    private struct ClipboardDocument: Sendable { let payload: ClipboardPayload; let normalizedText: String; let title: String; let type: ContentType }
    private struct LearningKey: Hashable { let query: String; let id: SavedItemID; let app: String? }
    private var saved: [SavedItemID: SavedDocument] = [:]
    private var clipboard: [ClipboardEventID: ClipboardDocument] = [:]
    private var learning: [LearningKey: (count: Int, last: Date)] = [:]
    private let maximumDocuments: Int

    public init(maximumDocuments: Int = 2_000) { self.maximumDocuments = maximumDocuments }
    public func rebuild(savedItems: [SavedItem], clipboardEvents: [ClipboardPayload]) {
        saved.removeAll(keepingCapacity: true); clipboard.removeAll(keepingCapacity: true)
        for item in savedItems.prefix(maximumDocuments) where item.archivedAt == nil { upsert(item) }
        for payload in clipboardEvents.prefix(maximumDocuments) { upsert(payload) }
    }
    public func upsert(_ item: SavedItem) {
        saved[item.id] = .init(item: item, normalizedTitle: normalize(item.title), terms: item.matchTerms.map { normalize($0.value) }, bodyTokens: tokens(item.plainContent), tagTokens: tokens(item.tags.joined(separator: " ")))
    }
    public func upsert(_ payload: ClipboardPayload) {
        let text = payload.searchableText ?? ""
        let representation = payload.event.representations.first
        clipboard[payload.event.id] = .init(payload: payload, normalizedText: normalize(text), title: representation?.displayMetadata ?? typeLabel(representation?.contentType ?? .unsupported), type: representation?.contentType ?? .unsupported)
    }
    public func remove(savedItemID: SavedItemID) { saved.removeValue(forKey: savedItemID) }
    public func remove(clipboardEventID: ClipboardEventID) { clipboard.removeValue(forKey: clipboardEventID) }
    public func purge() { saved.removeAll(); clipboard.removeAll(); learning.removeAll() }
    public func resetLearning() { learning.removeAll() }
    public func recordSelection(query: String, itemID: SavedItemID, appBundleID: String?, at date: Date = .now) {
        let key = LearningKey(query: normalize(query), id: itemID, app: appBundleID)
        let old = learning[key]; learning[key] = ((old?.count ?? 0) + 1, date)
    }

    public func search(_ query: String, scope: SearchScope, appBundleID: String? = nil, limit: Int = 8, includeAllWhenEmpty: Bool = false) -> [SearchResult] {
        let q = normalize(query); guard limit > 0, !q.isEmpty || includeAllWhenEmpty else { return [] }
        switch scope {
        case .saved:
            return saved.values.compactMap { document -> SearchResult? in
                let item = document.item; var score = 0; var reason = q.isEmpty ? "Recently saved" : "Fuzzy match"
                let learned = learning[LearningKey(query: q, id: item.id, app: appBundleID)] ?? learning[LearningKey(query: q, id: item.id, app: nil)]
                if q.isEmpty { score = Int(item.updatedAt.timeIntervalSince1970 / 86_400) }
                else if document.terms.contains(q) { score += 10_000; reason = "Exact match term" }
                else if document.terms.contains(where: { $0.hasPrefix(q) }) { score += 8_000; reason = "Match term" }
                else if document.normalizedTitle == q { score += 7_000; reason = "Matched title" }
                else if document.normalizedTitle.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { score += 6_000; reason = "Matched title" }
                else {
                    let distance = boundedLevenshtein(q, document.normalizedTitle, maximum: max(2, q.count / 3))
                    if document.normalizedTitle.contains(q) { score += 3_000 }
                    else if document.bodyTokens.contains(where: { $0.hasPrefix(q) }) || document.tagTokens.contains(where: { $0.hasPrefix(q) }) { score += 2_000 }
                    else if let distance { score += 1_000 - distance * 100 }
                    else if learned != nil { score += 500 }
                    else { return nil }
                }
                score += (learned?.count ?? 0) * 300 + (item.isPinned ? 200 : 0) + min(item.useCount, 100)
                return .init(source: .saved(item.id), score: score, reason: learned == nil ? reason : "Previously selected", title: item.title, preview: item.plainContent, contentType: .plainText)
            }.sorted(by: resultOrder).prefix(min(limit, 50)).map { $0 }
        case .clipboard:
            return clipboard.values.compactMap { document in
                let score: Int
                if q.isEmpty { score = 0 }
                else if document.normalizedText.hasPrefix(q) { score = 5_000 }
                else if document.normalizedText.contains(q) { score = 3_000 }
                else if boundedLevenshtein(q, String(document.normalizedText.prefix(max(q.count, 1))), maximum: 2) != nil { score = 1_000 }
                else { return nil }
                return .init(source: .clipboard(document.payload.event.id), score: score + Int(document.payload.event.capturedAt.timeIntervalSince1970 / 86_400), reason: "Clipboard", title: document.title, preview: document.payload.searchableText, contentType: document.type)
            }.sorted(by: resultOrder).prefix(min(limit, 50)).map { $0 }
        }
    }

    private func resultOrder(_ a: SearchResult, _ b: SearchResult) -> Bool { a.score != b.score ? a.score > b.score : String(describing: a.source) < String(describing: b.source) }
    private func normalize(_ value: String) -> String { value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private func tokens(_ value: String) -> Set<String> { Set(normalize(value).split { !$0.isLetter && !$0.isNumber }.map(String.init)) }
    private func typeLabel(_ type: ContentType) -> String { switch type { case .plainText: "Text"; case .richText: "Rich text"; case .url: "Link"; case .image: "Image"; case .fileReference: "File"; case .mediaReference: "Media"; case .unsupported: "Unsupported" } }
    private func boundedLevenshtein(_ lhs: String, _ rhs: String, maximum: Int) -> Int? {
        let a = Array(lhs), b = Array(rhs.prefix(max(lhs.count + maximum, 1))); if abs(a.count - b.count) > maximum { return nil }
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() { var current = [i + 1]; var rowMinimum = i + 1; for (j, y) in b.enumerated() { let value = min(current[j] + 1, previous[j + 1] + 1, previous[j] + (x == y ? 0 : 1)); current.append(value); rowMinimum = min(rowMinimum, value) }; if rowMinimum > maximum { return nil }; previous = current }
        return previous.last.map { $0 <= maximum ? $0 : nil } ?? nil
    }
}

public actor QueryLearningService {
    private let repository: EncryptedSQLiteRepository
    private let index: InMemorySearchIndex
    public init(repository: EncryptedSQLiteRepository, index: InMemorySearchIndex) { self.repository = repository; self.index = index }
    public func load() async throws {
        for signal in try await repository.recallSignals() {
            for _ in 0..<min(signal.selectionCount, 1_000) { await index.recordSelection(query: signal.query, itemID: .init(signal.itemID), appBundleID: signal.appBundleID, at: signal.lastSelectedAt) }
        }
    }
    public func recordExplicitSelection(query: String, itemID: SavedItemID, appBundleID: String?, at date: Date = .now) async throws {
        let normalized = query.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        let existing = try await repository.recallSignals().first { $0.query == normalized && $0.itemID == itemID.rawValue && $0.appBundleID == appBundleID }
        let signal = EncryptedSQLiteRepository.StoredRecallSignal(id: existing?.id ?? UUID(), query: normalized, itemID: itemID.rawValue, appBundleID: appBundleID, selectionCount: (existing?.selectionCount ?? 0) + 1, lastSelectedAt: date)
        try await repository.saveRecallSignal(signal)
        await index.recordSelection(query: normalized, itemID: itemID, appBundleID: appBundleID, at: date)
    }
    public func reset() async throws { try await repository.resetRecallSignals(); await index.resetLearning() }
}
