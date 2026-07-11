import AppKit
import CryptoKit
import Foundation
import KoruDomain
import UniformTypeIdentifiers

public enum PasteboardAccessState: String, Sendable { case unknown, available, denied, unavailable }
public enum PasteboardDecodeError: Error, Equatable, Sendable { case disabled; case denied; case excluded; case malformed; case oversized; case unsupported }

public struct PasteboardLimits: Hashable, Sendable {
    public var maximumItemCount = 32
    public var maximumTextBytes = 2 * 1024 * 1024
    public var maximumRichBytes = 8 * 1024 * 1024
    public var maximumImageBytes = 25 * 1024 * 1024
    public var maximumPixels = 40_000_000
    public var maximumTotalAllocation = 32 * 1024 * 1024
    public init() {}
}

public struct MaterializedPasteboardItem: Hashable, Sendable {
    public enum Value: Hashable, Sendable { case data(Data); case reference(String) }
    public let contentType: ContentType
    public let value: Value
    public let displayMetadata: String?
    public init(contentType: ContentType, value: Value, displayMetadata: String? = nil) { self.contentType = contentType; self.value = value; self.displayMetadata = displayMetadata }
}

public protocol PasteboardSnapshotSource: Sendable {
    func changeCount() -> Int
    func accessState() -> PasteboardAccessState
    func materialize(limits: PasteboardLimits) throws -> [[MaterializedPasteboardItem]]
}

public final class GeneralPasteboardSource: PasteboardSnapshotSource, @unchecked Sendable {
    public init() {}
    public func changeCount() -> Int { NSPasteboard.general.changeCount }
    public func accessState() -> PasteboardAccessState {
        if #available(macOS 15.4, *) {
            switch NSPasteboard.general.accessBehavior {
            case .alwaysDeny: return .denied
            case .alwaysAllow, .ask, .default: return .available
            @unknown default: return .unavailable
            }
        }
        return .available
    }

    public func materialize(limits: PasteboardLimits) throws -> [[MaterializedPasteboardItem]] {
        guard accessState() == .available else { throw PasteboardDecodeError.denied }
        let items = NSPasteboard.general.pasteboardItems ?? []
        guard items.count <= limits.maximumItemCount else { throw PasteboardDecodeError.oversized }
        var allocation = 0
        return try items.compactMap { item in
            var values: [MaterializedPasteboardItem] = []
            func appendData(_ type: NSPasteboard.PasteboardType, contentType: ContentType, limit: Int) throws {
                guard item.types.contains(type), let data = item.data(forType: type) else { return }
                guard data.count <= limit, allocation + data.count <= limits.maximumTotalAllocation else { throw PasteboardDecodeError.oversized }
                allocation += data.count; values.append(.init(contentType: contentType, value: .data(data)))
            }
            try appendData(.string, contentType: .plainText, limit: limits.maximumTextBytes)
            try appendData(.rtf, contentType: .richText, limit: limits.maximumRichBytes)
            try appendData(.html, contentType: .richText, limit: limits.maximumRichBytes)
            if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString), url.isFileURL {
                let isMedia = ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased())
                values.append(.init(contentType: isMedia ? .mediaReference : .fileReference, value: .reference(url.absoluteString), displayMetadata: url.lastPathComponent))
            } else if let url = item.string(forType: .URL) {
                let data = Data(url.utf8); guard data.count <= limits.maximumTextBytes else { throw PasteboardDecodeError.oversized }
                allocation += data.count; values.append(.init(contentType: .url, value: .data(data)))
            }
            let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
            if let type = imageTypes.first(where: item.types.contains), let data = item.data(forType: type) {
                guard data.count <= limits.maximumImageBytes, allocation + data.count <= limits.maximumTotalAllocation else { throw PasteboardDecodeError.oversized }
                allocation += data.count; values.append(.init(contentType: .image, value: .data(data)))
            }
            return values.isEmpty ? nil : values
        }
    }
}

public actor ExclusionPolicy {
    public static let builtInVersion = 1
    public static let defaultSensitiveBundleIDs: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
        "com.apple.keychainaccess", "com.apple.Passwords", "org.keepassxc.keepassxc",
    ]
    private var neverObserve: Set<String>
    private var neverSaveClipboard: Set<String>
    public init(neverObserve: Set<String> = [], neverSaveClipboard: Set<String> = []) {
        self.neverObserve = neverObserve.union(Self.defaultSensitiveBundleIDs)
        self.neverSaveClipboard = neverSaveClipboard.union(Self.defaultSensitiveBundleIDs)
    }
    public func mayObserve(_ bundleID: String?) -> Bool { guard let bundleID else { return false }; return !neverObserve.contains(bundleID) }
    public func maySaveClipboard(from bundleID: String?) -> Bool { guard let bundleID else { return false }; return !neverSaveClipboard.contains(bundleID) }
    public func setNeverSaveClipboard(_ values: Set<String>) { neverSaveClipboard = values.union(Self.defaultSensitiveBundleIDs) }
    public func neverSaveClipboardList() -> Set<String> { neverSaveClipboard }
}

public actor PasteboardMonitor {
    private let source: any PasteboardSnapshotSource
    private let repository: EncryptedSQLiteRepository
    private let assets: EncryptedAssetStore
    private let keys: VaultKeyManager
    private let exclusions: ExclusionPolicy
    private let limits: PasteboardLimits
    private var enabled = false
    private var suspended = false
    private var lastChangeCount: Int
    private var suppressedChangeCounts: Set<Int> = []
    private var policy: RetentionPolicy

    public init(source: any PasteboardSnapshotSource = GeneralPasteboardSource(), repository: EncryptedSQLiteRepository, assets: EncryptedAssetStore, keys: VaultKeyManager, exclusions: ExclusionPolicy, policy: RetentionPolicy = .v1Defaults, limits: PasteboardLimits = .init()) {
        self.source = source; self.repository = repository; self.assets = assets; self.keys = keys; self.exclusions = exclusions; self.policy = policy; self.limits = limits
        lastChangeCount = source.changeCount()
    }
    public func setEnabled(_ value: Bool) { enabled = value; policy.clipboardHistoryEnabled = value; lastChangeCount = source.changeCount() }
    public func suspend() { suspended = true }
    public func resume() { suspended = false; lastChangeCount = source.changeCount() }
    public func isEnabled() -> Bool { enabled }
    public func accessState() -> PasteboardAccessState { source.accessState() }
    public func updatePolicy(_ value: RetentionPolicy) { policy = value; enabled = value.clipboardHistoryEnabled }
    public func suppressKoruOriginatedChange(_ changeCount: Int) { suppressedChangeCounts.insert(changeCount) }

    @discardableResult public func poll(frontmostBundleID: String?, now: Date = .now) async throws -> ClipboardEventID? {
        guard enabled, policy.clipboardHistoryEnabled, !suspended else { throw PasteboardDecodeError.disabled }
        let count = source.changeCount(); guard count != lastChangeCount else { return nil }; lastChangeCount = count
        if suppressedChangeCounts.remove(count) != nil { return nil }
        guard source.accessState() == .available else { throw PasteboardDecodeError.denied }
        guard await exclusions.maySaveClipboard(from: frontmostBundleID) else { throw PasteboardDecodeError.excluded }
        let groups = try source.materialize(limits: limits)
        guard !groups.isEmpty else { throw PasteboardDecodeError.unsupported }
        let canonical = try canonicalData(groups)
        let digest = try await keys.withKey { VaultCipher.keyedDigest(canonical, using: $0) }
        if try await repository.clipboardEvents().contains(where: { $0.keyedContentDigest == digest }) { return nil }
        var representations: [ClipboardRepresentation] = []; var searchable: [String] = []
        for group in groups { for item in group {
            switch item.value {
            case .data(let data):
                let reference: EncryptedAssetReference
                if item.contentType == .image { reference = try await assets.storeImage(data, maximumBytes: policy.maximumImageBytes).asset }
                else { reference = try await assets.store(data) }
                if [.plainText, .url].contains(item.contentType), let text = String(data: data, encoding: .utf8) { searchable.append(text) }
                representations.append(.init(contentType: item.contentType, encryptedPayloadReference: reference.opaqueName, displayMetadata: item.displayMetadata, byteSize: data.count))
            case .reference(let reference):
                let encrypted = try await assets.store(Data(reference.utf8))
                representations.append(.init(contentType: item.contentType, encryptedPayloadReference: encrypted.opaqueName, displayMetadata: item.displayMetadata, byteSize: 0))
            }
        } }
        let event = ClipboardEvent(capturedAt: now, expiresAt: now.addingTimeInterval(policy.maximumAge), representations: representations)
        try await repository.saveClipboard(.init(event: event, searchableText: searchable.isEmpty ? nil : searchable.joined(separator: "\n"), sourceBundleIdentifier: frontmostBundleID, keyedContentDigest: digest))
        _ = try await repository.applyRetention(policy, now: now)
        return event.id
    }
    private func canonicalData(_ groups: [[MaterializedPasteboardItem]]) throws -> Data {
        var data = Data()
        for group in groups { data.append(0x1e); for item in group { data.append(contentsOf: item.contentType.rawValue.utf8); switch item.value { case .data(let value): data.append(value); case .reference(let value): data.append(contentsOf: value.utf8) }; data.append(0x1f) } }
        guard data.count <= limits.maximumTotalAllocation + 4096 else { throw PasteboardDecodeError.oversized }; return data
    }
}

public enum ClipboardRecallError: Error, Equatable, Sendable { case ineligibleTypedInvocation; case unavailable; case missingFile; case unsupportedTarget }
public struct ClipboardRecallSession: Hashable, Sendable {
    public var originalCommandSpan: Range<Int>?
    public var focusedQuery: String
    public var results: [SearchResult]
}

public actor ClipboardRecallService {
    private let search: InMemorySearchIndex
    public init(search: InMemorySearchIndex) { self.search = search }
    public func typedCLP(verifiedFreshStart: Bool, commandSpan: Range<Int>) async throws -> ClipboardRecallSession {
        guard verifiedFreshStart else { throw ClipboardRecallError.ineligibleTypedInvocation }
        return .init(originalCommandSpan: commandSpan, focusedQuery: "", results: [])
    }
    public func manualHotKey() -> ClipboardRecallSession { .init(originalCommandSpan: nil, focusedQuery: "", results: []) }
    public func focusSearch(_ query: String, session: ClipboardRecallSession, limit: Int = 8) async -> ClipboardRecallSession {
        var result = session; result.focusedQuery = query; result.results = await search.search(query, scope: .clipboard, limit: limit); return result
    }
}

public actor ClipboardHistoryController {
    private let monitor: PasteboardMonitor
    private let repository: EncryptedSQLiteRepository
    private let search: InMemorySearchIndex
    private let exclusions: ExclusionPolicy
    private var policy: RetentionPolicy
    public init(monitor: PasteboardMonitor, repository: EncryptedSQLiteRepository, search: InMemorySearchIndex, exclusions: ExclusionPolicy, policy: RetentionPolicy = .v1Defaults) { self.monitor = monitor; self.repository = repository; self.search = search; self.exclusions = exclusions; self.policy = policy }
    public func setEnabled(_ value: Bool) async { policy.clipboardHistoryEnabled = value; await monitor.updatePolicy(policy) }
    public func updateRetention(_ newPolicy: RetentionPolicy) async throws { policy = newPolicy; await monitor.updatePolicy(policy); for id in try await repository.applyRetention(policy) { await search.remove(clipboardEventID: id) } }
    public func clearHistory() async throws { try await repository.clearClipboard(); let active = try await repository.savedItems(states: [.active]); await search.rebuild(savedItems: active, clipboardEvents: []) }
    public func summary() async throws -> ClipboardStorageSummary { try await repository.storageSummary() }
    public func accessState() async -> PasteboardAccessState { await monitor.accessState() }
    public func setNeverSaveClipboardFrom(_ ids: Set<String>) async { await exclusions.setNeverSaveClipboard(ids) }
    public func saveToLibrary(eventID: ClipboardEventID, title: String, behavior: SavedItemBehavior = .savedText) async throws -> SavedItem {
        guard let payload = try await repository.clipboardEvents().first(where: { $0.event.id == eventID }), let content = payload.searchableText else { throw ClipboardRecallError.unavailable }
        let item = SavedItem(title: title, behavior: behavior, plainContent: content)
        try await repository.save(item); await search.upsert(item); return item
    }
}
