import Foundation

public protocol SavedItemRepository: Sendable {
    func item(id: SavedItemID) async throws -> SavedItem?
    func save(_ item: SavedItem) async throws
}

public protocol Clock: Sendable { var now: Date { get } }

public enum KoruPolicy {
    public static let minimumMacOS = "13.0"
    public static let reservedClipboardCommand = "clp"
    public static let allowsAutomaticInsertion = false
    public static let allowsBackgroundNetwork = false
    public static let clipboardStartsEnabled = false
}
