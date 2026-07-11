import Foundation

public protocol SavedItemRepository: Sendable {
    func item(id: SavedItemID) async throws -> SavedItem?
    func items(in collection: SavedItemCollection) async throws -> [SavedItem]
    func save(_ item: SavedItem) async throws
    func move(id: SavedItemID, to collection: SavedItemCollection) async throws
    func permanentlyDelete(id: SavedItemID) async throws
}

public protocol PermissionCoordinating: Sendable {
    func snapshot() async -> PermissionSnapshot
    func request(_ permission: KoruPermission) async -> PermissionState
    func openSystemSettings(for permission: KoruPermission) async
}

public protocol KoruSettingsServicing: Sendable {
    func snapshot() async -> KoruSettingsSnapshot
    func apply(_ snapshot: KoruSettingsSnapshot) async throws
    func clearClipboardHistory() async throws
    func resetVault() async throws
}

public protocol DiagnosticsServicing: Sendable {
    func snapshot() async -> DiagnosticsSnapshot
    func events() async -> [DiagnosticEvent]
    func perform(_ action: RecoveryAction) async -> RecoveryOutcome
}

public protocol Clock: Sendable { var now: Date { get } }

public enum KoruPolicy {
    public static let minimumMacOS = "13.0"
    public static let reservedClipboardCommand = "clp"
    public static let allowsAutomaticInsertion = false
    public static let allowsBackgroundNetwork = false
    public static let clipboardStartsEnabled = false
}
