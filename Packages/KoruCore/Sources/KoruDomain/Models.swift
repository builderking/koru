import Foundation

public struct StableID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public var description: String { rawValue.uuidString }
}

public enum SavedItemTag: Sendable {}
public enum TemplateFieldTag: Sendable {}
public enum ClipboardEventTag: Sendable {}
public enum RecallSignalTag: Sendable {}

public typealias SavedItemID = StableID<SavedItemTag>
public typealias TemplateFieldID = StableID<TemplateFieldTag>
public typealias ClipboardEventID = StableID<ClipboardEventTag>
public typealias RecallSignalID = StableID<RecallSignalTag>

public enum SavedItemBehavior: String, Codable, CaseIterable, Sendable {
    case savedText
    case quickReplacement
    case template
}

public struct MatchTerm: Hashable, Codable, Sendable {
    public var value: String
    public var isPreferredInitialTerm: Bool
    public var isExactTrigger: Bool

    public init(value: String, isPreferredInitialTerm: Bool = false, isExactTrigger: Bool = false) {
        self.value = value
        self.isPreferredInitialTerm = isPreferredInitialTerm
        self.isExactTrigger = isExactTrigger
    }
}

public struct TemplateField: Identifiable, Hashable, Codable, Sendable {
    public enum InputType: String, Codable, Sendable { case singleLine, multiline }
    public var id: TemplateFieldID
    public var token: String
    public var label: String
    public var helpText: String?
    public var isRequired: Bool
    public var defaultValue: String?
    public var order: Int
    public var inputType: InputType

    public init(id: TemplateFieldID = .init(), token: String, label: String, helpText: String? = nil, isRequired: Bool = false, defaultValue: String? = nil, order: Int, inputType: InputType = .singleLine) {
        self.id = id; self.token = token; self.label = label; self.helpText = helpText
        self.isRequired = isRequired; self.defaultValue = defaultValue; self.order = order; self.inputType = inputType
    }
}

public struct SavedItem: Identifiable, Hashable, Codable, Sendable {
    public static let currentSchemaVersion = 1
    public var id: SavedItemID
    public var schemaVersion: Int
    public var title: String
    public var behavior: SavedItemBehavior
    public var plainContent: String
    public var matchTerms: [MatchTerm]
    public var tags: [String]
    public var templateFields: [TemplateField]
    public var isPinned: Bool
    public var archivedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
    public var useCount: Int
    public var sourceContext: String?
    public var keyedContentDigest: Data?

    public init(id: SavedItemID = .init(), schemaVersion: Int = currentSchemaVersion, title: String, behavior: SavedItemBehavior, plainContent: String, matchTerms: [MatchTerm] = [], tags: [String] = [], templateFields: [TemplateField] = [], isPinned: Bool = false, archivedAt: Date? = nil, createdAt: Date = .now, updatedAt: Date = .now, lastUsedAt: Date? = nil, useCount: Int = 0, sourceContext: String? = nil, keyedContentDigest: Data? = nil) {
        self.id = id; self.schemaVersion = schemaVersion; self.title = title; self.behavior = behavior
        self.plainContent = plainContent; self.matchTerms = matchTerms; self.tags = tags; self.templateFields = templateFields
        self.isPinned = isPinned; self.archivedAt = archivedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt; self.useCount = useCount; self.sourceContext = sourceContext; self.keyedContentDigest = keyedContentDigest
    }
}

public enum ContentType: String, Codable, CaseIterable, Sendable { case plainText, richText, url, image, fileReference, mediaReference, unsupported }
public enum ClipboardAvailability: String, Codable, Sendable { case available, expired, missingSourceFile, unsupported, skipped }

public struct ClipboardRepresentation: Hashable, Codable, Sendable {
    public var contentType: ContentType
    public var encryptedPayloadReference: String?
    public var displayMetadata: String?
    public var byteSize: Int
    public init(contentType: ContentType, encryptedPayloadReference: String? = nil, displayMetadata: String? = nil, byteSize: Int = 0) {
        self.contentType = contentType; self.encryptedPayloadReference = encryptedPayloadReference
        self.displayMetadata = displayMetadata; self.byteSize = byteSize
    }
}

public struct ClipboardEvent: Identifiable, Hashable, Codable, Sendable {
    public var id: ClipboardEventID
    public var capturedAt: Date
    public var expiresAt: Date
    public var representations: [ClipboardRepresentation]
    public var encryptedSourceContext: Data?
    public var availability: ClipboardAvailability
    public init(id: ClipboardEventID = .init(), capturedAt: Date = .now, expiresAt: Date, representations: [ClipboardRepresentation], encryptedSourceContext: Data? = nil, availability: ClipboardAvailability = .available) {
        self.id = id; self.capturedAt = capturedAt; self.expiresAt = expiresAt; self.representations = representations
        self.encryptedSourceContext = encryptedSourceContext; self.availability = availability
    }
}

public struct RecallSignal: Identifiable, Hashable, Codable, Sendable {
    public var id: RecallSignalID
    public var encryptedNormalizedQuery: Data
    public var savedItemID: SavedItemID
    public var selectionCount: Int
    public var lastSelectedAt: Date
    public var encryptedDestinationAppID: Data?
}

public struct AppExclusion: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case neverObserve, neverSaveClipboardFrom }
    public var encryptedBundleIdentifier: Data
    public var kind: Kind
    public var isBuiltIn: Bool
}

public struct RetentionPolicy: Hashable, Codable, Sendable {
    public static let candidate = RetentionPolicy(maximumAge: 7 * 24 * 60 * 60, maximumEvents: 500, maximumAssetBytes: 256 * 1024 * 1024, maximumImageBytes: 25 * 1024 * 1024)
    public var maximumAge: TimeInterval
    public var maximumEvents: Int
    public var maximumAssetBytes: Int
    public var maximumImageBytes: Int
    public var clipboardHistoryEnabled: Bool
    public init(maximumAge: TimeInterval, maximumEvents: Int, maximumAssetBytes: Int, maximumImageBytes: Int, clipboardHistoryEnabled: Bool = false) {
        self.maximumAge = maximumAge; self.maximumEvents = maximumEvents; self.maximumAssetBytes = maximumAssetBytes
        self.maximumImageBytes = maximumImageBytes; self.clipboardHistoryEnabled = clipboardHistoryEnabled
    }
}

public enum CompatibilityCapability: String, Codable, CaseIterable, Sendable { case full, paste, copyOnly, paletteOnly, blocked }
public enum InsertionTier: String, Codable, Sendable { case directAccessibility, pasteboardAndPaste, copyOnly }
public enum InvocationMode: String, Codable, Sendable { case initialTypedMatch, clipboardCommand, manualRecall }

public struct TargetSnapshot: Hashable, Codable, Sendable {
    public var processIdentifier: Int32
    public var elementToken: String
    public var replacementLocation: Int
    public var replacementLength: Int
    public var expectedValueDigest: Data?
    public init(processIdentifier: Int32, elementToken: String, replacementLocation: Int, replacementLength: Int, expectedValueDigest: Data? = nil) {
        self.processIdentifier = processIdentifier; self.elementToken = elementToken; self.replacementLocation = replacementLocation
        self.replacementLength = replacementLength; self.expectedValueDigest = expectedValueDigest
    }
}

public struct InsertionTransaction: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var invocation: InvocationMode
    public var target: TargetSnapshot
    public var selectedItemID: SavedItemID?
    public var requestedTier: InsertionTier
    public var explicitlyConfirmed: Bool
    public init(id: UUID = UUID(), invocation: InvocationMode, target: TargetSnapshot, selectedItemID: SavedItemID? = nil, requestedTier: InsertionTier, explicitlyConfirmed: Bool = false) {
        self.id = id; self.invocation = invocation; self.target = target; self.selectedItemID = selectedItemID
        self.requestedTier = requestedTier; self.explicitlyConfirmed = explicitlyConfirmed
    }
}

public enum PermissionState: String, Codable, Sendable { case unknown, unavailable, denied, granted, revoked }
public enum HotKeyState: String, Codable, Sendable { case registered, disabled, conflict, reservedOrUnsupported, failed }
public struct PermissionSnapshot: Hashable, Codable, Sendable {
    public var accessibility: PermissionState
    public var inputListening: PermissionState
    public var eventPosting: PermissionState
    public var pasteboard: PermissionState
    public var loginItem: PermissionState
    public var hotKeys: [String: HotKeyState]
}

public struct DiagnosticEvent: Identifiable, Hashable, Codable, Sendable {
    public enum Severity: String, Codable, Sendable { case debug, info, notice, warning, error }
    public let id: UUID
    public var code: String
    public var severity: Severity
    public var timestamp: Date
    public var result: String
    public var durationMilliseconds: Double?
    public var aggregateCount: Int?
    public init(id: UUID = UUID(), code: String, severity: Severity, timestamp: Date = .now, result: String, durationMilliseconds: Double? = nil, aggregateCount: Int? = nil) {
        self.id = id; self.code = code; self.severity = severity; self.timestamp = timestamp; self.result = result
        self.durationMilliseconds = durationMilliseconds; self.aggregateCount = aggregateCount
    }
}
