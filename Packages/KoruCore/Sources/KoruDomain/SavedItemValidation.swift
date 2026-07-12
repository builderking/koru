import Foundation

public enum ProductValidationError: LocalizedError, Equatable, Sendable {
    case emptyTitle
    case emptyContent
    case emptyTags
    case triggerTagTooShort
    case triggerTagTooLong
    case reservedMatchTerm
    case duplicateMatchTerm
    case missingRequiredField(String)
    case malformedTemplate(String)
    case unsupportedImportVersion(Int)
    case malformedImport
    case duplicateItems(Int)

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: "Enter a title."
        case .emptyContent: "Enter content to save."
        case .emptyTags: "Add at least one tag."
        case .triggerTagTooShort: "Each tag must be at least \(KoruPolicy.minimumTriggerLength) characters."
        case .triggerTagTooLong: "Each tag must be at most \(KoruPolicy.maximumTriggerLength) characters."
        case .reservedMatchTerm: "“clp” is reserved for Clipboard."
        case .duplicateMatchTerm: "Tags must be unique."
        case .missingRequiredField(let label): "Complete \(label)."
        case .malformedTemplate(let token): "Template placeholder \(token) is invalid."
        case .unsupportedImportVersion(let version): "Import version \(version) is not supported."
        case .malformedImport: "The selected file is not a valid Koru export."
        case .duplicateItems(let count): "The import contains \(count) duplicate item(s)."
        }
    }
}

public enum SavedItemValidation {
    /// Validates tags at every save boundary. Commas are parsed by the editor, so a value such as
    /// "client follow up" remains one tag here.
    public static func validatedTriggerTags(content: String, triggerTags: [String]) throws -> [String] {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProductValidationError.emptyContent
        }
        let trimmed = triggerTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { throw ProductValidationError.emptyTags }
        guard trimmed.allSatisfy({ $0.count >= KoruPolicy.minimumTriggerLength }) else {
            throw ProductValidationError.triggerTagTooShort
        }
        guard trimmed.allSatisfy({ $0.count <= KoruPolicy.maximumTriggerLength }) else {
            throw ProductValidationError.triggerTagTooLong
        }
        let normalized = trimmed.map(SavedItem.normalizedTriggerTag)
        guard !normalized.contains(KoruPolicy.reservedClipboardCommand) else {
            throw ProductValidationError.reservedMatchTerm
        }
        guard Set(normalized).count == normalized.count else {
            throw ProductValidationError.duplicateMatchTerm
        }
        return trimmed
    }

    /// Produces the encoded compatibility shape for a newly saved or edited item. New `tags` take
    /// precedence; legacy callers that still supply only `matchTerms` remain saveable.
    public static func preparedForSave(_ candidate: SavedItem) throws -> SavedItem {
        var item = candidate
        let sourceTags = item.tags.isEmpty ? item.matchTerms.map(\.value) : item.tags
        let tags = try validatedTriggerTags(content: item.plainContent, triggerTags: sourceTags)
        item.title = item.displayTitle
        item.behavior = .savedText
        item.tags = tags
        item.matchTerms = tags.map {
            MatchTerm(value: $0, isPreferredInitialTerm: true, isExactTrigger: true)
        }
        item.templateFields = []
        return item
    }
}
