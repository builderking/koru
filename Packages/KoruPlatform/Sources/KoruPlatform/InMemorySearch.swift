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

/// A saved item whose assigned trigger exactly matches the text ending at the caret.
/// `replacementRange` uses Accessibility's UTF-16 coordinate space so callers can replace
/// the typed trigger without translating offsets from a folded/normalized string.
public struct ExactTriggerMatch: Hashable, Sendable {
    public let result: SearchResult
    public let trigger: String
    public let replacementRange: NSRange

    public init(result: SearchResult, trigger: String, replacementRange: NSRange) {
        self.result = result
        self.trigger = trigger
        self.replacementRange = replacementRange
    }
}

public actor InMemorySearchIndex {
    private struct SavedDocument: Sendable { let item: SavedItem; let normalizedTags: [String]; let normalizedContent: String; let bodyTokens: Set<String> }
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
        saved[item.id] = .init(item: item, normalizedTags: item.triggerTags.map(normalize), normalizedContent: normalize(item.plainContent), bodyTokens: tokens(item.plainContent))
    }
    public func upsert(_ payload: ClipboardPayload) {
        let text = payload.searchableText ?? ""
        // Prefer the image representation for mixed clipboard items so the helper can present the
        // real visual payload instead of reducing it to an accompanying text flavor.
        let representation = payload.event.representations.first(where: { $0.contentType == .image })
            ?? payload.event.representations.first
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

    /// Finds assigned tags that consume the suffix ending at `caretUTF16`.
    ///
    /// This path is intentionally separate from fuzzy/manual search: partial tags, titles, and
    /// content never open the automatic panel. Foundation performs the comparison directly in
    /// the original string so diacritic/width folding cannot corrupt the replacement range.
    public func exactTriggerMatches(in value: String, caretUTF16: Int, limit: Int = 8) -> [ExactTriggerMatch] {
        let source = value as NSString
        guard limit > 0, caretUTF16 >= 0, caretUTF16 <= source.length else { return [] }
        let prefixRange = NSRange(location: 0, length: caretUTF16)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .backwards, .anchored]
        var candidates: [(document: SavedDocument, trigger: String, range: NSRange)] = []

        for document in saved.values {
            for rawTrigger in document.item.triggerTags {
                let trigger = rawTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trigger.count >= KoruPolicy.minimumTriggerLength else { continue }
                let range = source.range(of: trigger, options: options, range: prefixRange)
                guard range.location != NSNotFound,
                      NSMaxRange(range) == caretUTF16,
                      hasLeftBoundary(in: source, match: range) else { continue }
                candidates.append((document, trigger, range))
            }
        }

        guard let longestLength = candidates.map(\.range.length).max() else { return [] }
        var onePerItem: [SavedItemID: (document: SavedDocument, trigger: String, range: NSRange)] = [:]
        for candidate in candidates where candidate.range.length == longestLength {
            let id = candidate.document.item.id
            if let existing = onePerItem[id],
               existing.trigger.localizedStandardCompare(candidate.trigger) != .orderedDescending { continue }
            onePerItem[id] = candidate
        }

        return onePerItem.values.map { candidate in
            let item = candidate.document.item
            let score = 10_000 + (item.isPinned ? 200 : 0) + min(item.useCount, 100)
            let result = SearchResult(source: .saved(item.id), score: score, reason: "Exact trigger", title: item.displayTitle, preview: item.plainContent, contentType: .plainText)
            return ExactTriggerMatch(result: result, trigger: candidate.trigger, replacementRange: candidate.range)
        }.sorted { lhs, rhs in
            resultOrder(lhs.result, rhs.result)
        }.prefix(min(limit, 50)).map { $0 }
    }

    public func search(_ query: String, scope: SearchScope, appBundleID: String? = nil, limit: Int = 8, includeAllWhenEmpty: Bool = false) -> [SearchResult] {
        let q = normalize(query); guard limit > 0, !q.isEmpty || includeAllWhenEmpty else { return [] }
        switch scope {
        case .saved:
            return saved.values.compactMap { document -> SearchResult? in
                let item = document.item; var score = 0; var reason = q.isEmpty ? "Recently saved" : "Fuzzy match"
                let learned = learning[LearningKey(query: q, id: item.id, app: appBundleID)] ?? learning[LearningKey(query: q, id: item.id, app: nil)]
                if q.isEmpty { score = Int(item.updatedAt.timeIntervalSince1970 / 86_400) }
                else if document.normalizedTags.contains(q) { score += 10_000; reason = "Exact tag" }
                else if document.normalizedTags.contains(where: { $0.hasPrefix(q) }) { score += 8_000; reason = "Matched tag" }
                else if document.normalizedTags.contains(where: { $0.contains(q) }) { score += 6_000; reason = "Matched tag" }
                else {
                    let distance = document.normalizedTags.compactMap { boundedLevenshtein(q, $0, maximum: max(2, q.count / 3)) }.min()
                    if document.normalizedContent.contains(q) { score += 3_000; reason = "Matched content" }
                    else if document.bodyTokens.contains(where: { $0.hasPrefix(q) }) { score += 2_000; reason = "Matched content" }
                    else if let distance { score += 1_000 - distance * 100; reason = "Fuzzy tag" }
                    else if learned != nil { score += 500 }
                    else { return nil }
                }
                score += (learned?.count ?? 0) * 300 + (item.isPinned ? 200 : 0) + min(item.useCount, 100)
                return .init(source: .saved(item.id), score: score, reason: learned == nil ? reason : "Previously selected", title: item.displayTitle, preview: item.plainContent, contentType: .plainText)
            }.sorted(by: resultOrder).prefix(min(limit, 50)).map { $0 }
        case .clipboard:
            return clipboard.values.compactMap { document in
                let score: Int
                if q.isEmpty {
                    guard !document.normalizedText.isEmpty || document.type == .image else { return nil }
                    score = 0
                }
                else if document.normalizedText.hasPrefix(q) { score = 5_000 }
                else if document.normalizedText.contains(q) { score = 3_000 }
                else if boundedLevenshtein(q, String(document.normalizedText.prefix(max(q.count, 1))), maximum: 2) != nil { score = 1_000 }
                else { return nil }
                return .init(source: .clipboard(document.payload.event.id), score: score + Int(document.payload.event.capturedAt.timeIntervalSince1970 / 86_400), reason: "Clipboard", title: document.title, preview: document.payload.searchableText, contentType: document.type)
            }.sorted(by: resultOrder).prefix(min(limit, 50)).map { $0 }
        }
    }

    private func resultOrder(_ a: SearchResult, _ b: SearchResult) -> Bool { a.score != b.score ? a.score > b.score : String(describing: a.source) < String(describing: b.source) }
    private func hasLeftBoundary(in value: NSString, match: NSRange) -> Bool {
        guard match.location > 0 else { return true }
        guard let preceding = value.substring(to: match.location).last else { return true }
        return !preceding.isLetter && !preceding.isNumber
    }
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
