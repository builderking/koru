import Foundation
import KoruDomain
import OSLog
import Combine

public enum ProductValidationError: LocalizedError, Equatable {
    case emptyTitle, emptyContent, reservedMatchTerm, duplicateMatchTerm, missingRequiredField(String), malformedTemplate(String), unsupportedImportVersion(Int), malformedImport, duplicateItems(Int)
    public var errorDescription: String? {
        switch self {
        case .emptyTitle: "Enter a title."
        case .emptyContent: "Enter content to save."
        case .reservedMatchTerm: "“clp” is reserved for Clipboard."
        case .duplicateMatchTerm: "Match terms must be unique."
        case .missingRequiredField(let label): "Complete \(label)."
        case .malformedTemplate(let token): "Template placeholder \(token) is invalid."
        case .unsupportedImportVersion(let version): "Import version \(version) is not supported."
        case .malformedImport: "The selected file is not a valid Koru export."
        case .duplicateItems(let count): "The import contains \(count) duplicate item(s)."
        }
    }
}

public enum DuplicateResolution: String, CaseIterable, Sendable { case skip, keepBoth, replace }

public struct TemplateDefinition: Equatable, Sendable {
    public var content: String
    public var fields: [TemplateField]
    public init(content: String, fields: [TemplateField]) { self.content = content; self.fields = fields }
}

public enum TemplateEngine {
    private static let expression = try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z][A-Za-z0-9_-]{0,63})\s*\}\}"#)
    public static func tokens(in content: String) -> [String] {
        let range = NSRange(content.startIndex..., in: content)
        var seen = Set<String>()
        return expression.matches(in: content, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            let token = String(content[range])
            return seen.insert(token).inserted ? token : nil
        }
    }
    public static func validate(_ definition: TemplateDefinition) throws {
        let parsed = Set(tokens(in: definition.content))
        let declared = Set(definition.fields.map(\.token))
        if parsed != declared { throw ProductValidationError.malformedTemplate(parsed.symmetricDifference(declared).sorted().first ?? "unknown") }
    }
    public static func render(_ definition: TemplateDefinition, values: [String: String]) throws -> String {
        try validate(definition)
        for field in definition.fields.sorted(by: { $0.order < $1.order }) where field.isRequired {
            let value = values[field.token] ?? field.defaultValue ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw ProductValidationError.missingRequiredField(field.label) }
        }
        var result = definition.content
        for field in definition.fields {
            let value = values[field.token] ?? field.defaultValue ?? ""
            let pattern = #"\{\{\s*"# + NSRegularExpression.escapedPattern(for: field.token) + #"\s*\}\}"#
            result = result.replacingOccurrences(of: pattern, with: value, options: .regularExpression)
        }
        return result
    }
}

public struct SavedItemExport: Codable, Sendable {
    public static let currentVersion = 1
    public var format: String = "dev.koru.saved-items"
    public var version: Int = currentVersion
    public var exportedAt: Date
    public var items: [SavedItem]
    public init(exportedAt: Date = .now, items: [SavedItem]) { self.exportedAt = exportedAt; self.items = items }
}

public struct ImportPreview: Sendable {
    public var items: [SavedItem]
    public var duplicateIDs: Set<SavedItemID>
    public var duplicateCount: Int { duplicateIDs.count }
}

public enum SavedItemTransfer {
    public static func encode(_ items: [SavedItem]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(SavedItemExport(items: items))
    }
    public static func preview(_ data: Data, existing: [SavedItem]) throws -> ImportPreview {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(SavedItemExport.self, from: data), payload.format == "dev.koru.saved-items" else { throw ProductValidationError.malformedImport }
        guard payload.version == SavedItemExport.currentVersion else { throw ProductValidationError.unsupportedImportVersion(payload.version) }
        let existingIDs = Set(existing.map(\.id)); let duplicates = Set(payload.items.map(\.id)).intersection(existingIDs)
        return ImportPreview(items: payload.items, duplicateIDs: duplicates)
    }
    public static func resolve(_ preview: ImportPreview, existing: [SavedItem], resolution: DuplicateResolution) -> [SavedItem] {
        switch resolution {
        case .skip: return preview.items.filter { !preview.duplicateIDs.contains($0.id) }
        case .replace: return preview.items
        case .keepBoth: return preview.items.map { item in
            guard preview.duplicateIDs.contains(item.id) else { return item }
            var copy = item; copy.id = .init(); copy.title += " copy"; copy.createdAt = .now; copy.updatedAt = .now; return copy
        }
        }
    }
}

public enum SafeDiagnosticValue: Hashable, Codable, Sendable { case code(String), integer(Int), milliseconds(Double), boolean(Bool) }
public struct StructuredDiagnostic: Identifiable, Hashable, Codable, Sendable {
    public var id = UUID(); public var timestamp = Date(); public var category: String; public var code: String; public var values: [String: SafeDiagnosticValue]
    public init(category: String, code: String, values: [String: SafeDiagnosticValue] = [:]) { self.category = category; self.code = code; self.values = values }
}

public actor PrivacySafeLogger {
    public static let allowedKeys: Set<String> = ["reason_code", "capability", "insertion_tier", "duration_ms", "count", "success", "state"]
    private let logger = Logger(subsystem: "dev.koru.app", category: "product")
    private var retained: [StructuredDiagnostic] = []
    private let limit: Int
    public init(limit: Int = 250) { self.limit = max(1, limit) }
    public func record(_ diagnostic: StructuredDiagnostic) {
        let values = diagnostic.values.filter { Self.allowedKeys.contains($0.key) }
        let safe = StructuredDiagnostic(category: diagnostic.category, code: diagnostic.code, values: values)
        retained.append(safe); if retained.count > limit { retained.removeFirst(retained.count - limit) }
        logger.log("\(safe.category, privacy: .public).\(safe.code, privacy: .public)")
    }
    public func events() -> [StructuredDiagnostic] { retained }
}

@MainActor public protocol ProductStoreProtocol: AnyObject {
    var items: [SavedItem] { get }
    var settings: KoruSettingsSnapshot { get }
    var permissionSnapshot: PermissionSnapshot { get }
    var diagnosticsSnapshot: DiagnosticsSnapshot { get }
    var diagnosticEvents: [DiagnosticEvent] { get }
    func save(_ item: SavedItem) throws
    func move(_ id: SavedItemID, to collection: SavedItemCollection)
    func permanentlyDelete(_ id: SavedItemID)
    func applySettings(_ settings: KoruSettingsSnapshot)
    func request(_ permission: KoruPermission)
    func refreshPermissions()
    func perform(_ action: RecoveryAction) async -> RecoveryOutcome
}

public struct ProductStorePersistence: Sendable {
    public var load: @Sendable () async throws -> [SavedItem]
    public var save: @Sendable (SavedItem) async throws -> Void
    public var move: @Sendable (SavedItemID, SavedItemCollection) async throws -> Void
    public var permanentlyDelete: @Sendable (SavedItemID) async throws -> Void
    public var reset: @Sendable () async throws -> Void
    public init(
        load: @escaping @Sendable () async throws -> [SavedItem],
        save: @escaping @Sendable (SavedItem) async throws -> Void,
        move: @escaping @Sendable (SavedItemID, SavedItemCollection) async throws -> Void,
        permanentlyDelete: @escaping @Sendable (SavedItemID) async throws -> Void,
        reset: @escaping @Sendable () async throws -> Void
    ) {
        self.load = load; self.save = save; self.move = move
        self.permanentlyDelete = permanentlyDelete; self.reset = reset
    }
}

@MainActor public final class ProductStore: ObservableObject, ProductStoreProtocol {
    @Published public private(set) var items: [SavedItem]
    @Published public private(set) var settings = KoruSettingsSnapshot()
    @Published public private(set) var permissionSnapshot: PermissionSnapshot
    @Published public private(set) var diagnosticsSnapshot: DiagnosticsSnapshot
    @Published public private(set) var diagnosticEvents: [DiagnosticEvent] = []
    @Published public var pendingDraft: SavedItem?
    private let logger = PrivacySafeLogger()
    private var persistence: ProductStorePersistence?
    public var onSettingsChanged: ((KoruSettingsSnapshot) -> Void)?
    public var onPermissionRequested: ((KoruPermission) -> Void)?
    public var onPermissionRefreshRequested: (() -> Void)?
    private var persistenceTasks: [UUID: Task<Void, Never>] = [:]
    public init(items: [SavedItem] = []) {
        self.items = items
        let permissions = PermissionSnapshot(accessibility: .unknown, inputListening: .unknown, eventPosting: .unknown, pasteboard: .unknown, loginItem: .unknown, hotKeys: [:])
        permissionSnapshot = permissions
        diagnosticsSnapshot = DiagnosticsSnapshot(appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development", osVersion: ProcessInfo.processInfo.operatingSystemVersionString, architecture: Self.architecture, permissions: permissions, eventTap: .stopped, accessibilityObserver: .stopped, pasteboardMonitor: .stopped, repository: .healthy, registeredHotKeys: [:], retainedClipboardCount: 0)
    }
    public func configurePersistence(_ persistence: ProductStorePersistence) {
        self.persistence = persistence
        Task { await reloadFromPersistence() }
    }
    public func presentDraft(_ item: SavedItem) { pendingDraft = item }
    public func reloadFromPersistence() async {
        guard let persistence else { return }
        do {
            items = try await persistence.load()
            diagnosticsSnapshot.repository = .healthy
        } catch {
            diagnosticsSnapshot.repository = .degraded
            await recordPersistenceFailure("repository.load_failed")
        }
    }
    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
    public func save(_ item: SavedItem) throws {
        guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProductValidationError.emptyTitle }
        guard !item.plainContent.isEmpty else { throw ProductValidationError.emptyContent }
        let normalized = item.matchTerms.map { $0.value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        if normalized.contains(KoruPolicy.reservedClipboardCommand) { throw ProductValidationError.reservedMatchTerm }
        if Set(normalized).count != normalized.count { throw ProductValidationError.duplicateMatchTerm }
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }
        if let persistence { enqueuePersistence("repository.save_failed") { try await persistence.save(item) } }
    }
    public func move(_ id: SavedItemID, to collection: SavedItemCollection) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch collection { case .active: items[index].archivedAt = nil; items[index].deletedAt = nil; case .archived: items[index].archivedAt = .now; items[index].deletedAt = nil; case .recentlyDeleted: items[index].deletedAt = .now }
        items[index].updatedAt = .now
        if let persistence { enqueuePersistence("repository.move_failed") { try await persistence.move(id, collection) } }
    }
    public func permanentlyDelete(_ id: SavedItemID) {
        items.removeAll { $0.id == id }
        if let persistence { enqueuePersistence("repository.delete_failed") { try await persistence.permanentlyDelete(id) } }
    }
    public func applySettings(_ value: KoruSettingsSnapshot) { settings = value; onSettingsChanged?(value); diagnosticsSnapshot.eventTap = value.typedMatchingEnabled && !value.isPaused ? .healthy : .stopped; diagnosticsSnapshot.pasteboardMonitor = value.clipboardHistoryEnabled && !value.isPaused ? .healthy : .stopped }
    public func updateRuntimeHealth(permissions: PermissionSnapshot, eventTap: ServiceHealth, recall: ServiceHealth) {
        permissionSnapshot = permissions; diagnosticsSnapshot.permissions = permissions
        diagnosticsSnapshot.eventTap = eventTap
        diagnosticsSnapshot.accessibilityObserver = recall
    }
    public func request(_ permission: KoruPermission) { onPermissionRequested?(permission) }
    public func refreshPermissions() { onPermissionRefreshRequested?() }
    public func perform(_ action: RecoveryAction) async -> RecoveryOutcome {
        if action == .resetVault {
            do { try await persistence?.reset(); items.removeAll() }
            catch { await recordPersistenceFailure("repository.reset_failed"); return .init(action: action, succeeded: false, reasonCode: "repository.reset_failed") }
        }
        if action == .clearClipboardHistory { diagnosticsSnapshot.retainedClipboardCount = 0 }
        if action == .retryServices { diagnosticsSnapshot.eventTap = settings.typedMatchingEnabled ? .healthy : .stopped }
        if action == .rebuildAccessibilityObserver { diagnosticsSnapshot.accessibilityObserver = .healthy }
        if action == .resumePasteboardMonitor { diagnosticsSnapshot.pasteboardMonitor = settings.clipboardHistoryEnabled ? .healthy : .stopped }
        let outcome = RecoveryOutcome(action: action, succeeded: true, reasonCode: "recovery.completed")
        diagnosticEvents.append(.init(code: outcome.reasonCode, severity: .notice, result: action.rawValue))
        await logger.record(.init(category: "recovery", code: outcome.reasonCode, values: ["success": .boolean(true)]))
        return outcome
    }
    private func recordPersistenceFailure(_ code: String) async {
        diagnosticsSnapshot.repository = .degraded
        diagnosticEvents.append(.init(code: code, severity: .error, result: "failed"))
        await logger.record(.init(category: "repository", code: code, values: ["success": .boolean(false)]))
    }
    private func enqueuePersistence(_ failureCode: String, operation: @escaping @Sendable () async throws -> Void) {
        let id = UUID()
        persistenceTasks[id] = Task {
            do { try await operation() }
            catch { await self.recordPersistenceFailure(failureCode) }
            self.persistenceTasks.removeValue(forKey: id)
        }
    }
    public func flushPersistence() async {
        for task in Array(persistenceTasks.values) { await task.value }
    }
}

public struct SupportBundle: Codable, Sendable {
    public var generatedAt: Date; public var snapshot: DiagnosticsSnapshot; public var events: [DiagnosticEvent]
    public init(generatedAt: Date = .now, snapshot: DiagnosticsSnapshot, events: [DiagnosticEvent]) { self.generatedAt = generatedAt; self.snapshot = snapshot; self.events = events }
    public func data() throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return try encoder.encode(self) }
}
