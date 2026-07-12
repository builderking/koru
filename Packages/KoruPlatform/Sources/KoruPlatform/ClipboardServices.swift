import AppKit
import CryptoKit
import Foundation
import ImageIO
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

public enum KoruPasteboardOrigin {
    public static let type = NSPasteboard.PasteboardType("dev.builderking.koru.origin")
    public static let value = "dev.builderking.koru"

    @discardableResult
    public static func write(_ text: String, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        guard pasteboard.setString(value, forType: type) else { return false }
        return pasteboard.setString(text, forType: .string)
    }

    @discardableResult
    public static func writeImage(_ content: ClipboardImageContent, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        guard pasteboard.setString(value, forType: type) else { return false }
        return pasteboard.setData(content.originalData, forType: content.format.pasteboardType)
    }
}

public enum ClipboardImageFormat: String, Equatable, Sendable {
    case png
    case tiff

    var pasteboardType: NSPasteboard.PasteboardType { self == .tiff ? .tiff : .png }
}

public struct ClipboardImageContent: Equatable, Sendable {
    public var originalData: Data
    public var thumbnailData: Data
    public var format: ClipboardImageFormat

    public init(originalData: Data, thumbnailData: Data, format: ClipboardImageFormat) {
        self.originalData = originalData
        self.thumbnailData = thumbnailData
        self.format = format
    }
}

public protocol ClipboardContentResolving: Sendable {
    func image(eventID: ClipboardEventID) async throws -> ClipboardImageContent?
    func thumbnail(eventID: ClipboardEventID, maximumBytes: Int) async throws -> Data?
}

/// Resolves only the bounded image representation requested by the clipboard helper. The full image
/// is decrypted on demand for an explicit selection; panel rows retain only the generated thumbnail.
public actor ClipboardContentResolver: ClipboardContentResolving {
    private let repository: EncryptedSQLiteRepository
    private let assets: EncryptedAssetStore
    private let maximumImageBytes: Int
    private let thumbnailPixels: Int

    public init(repository: EncryptedSQLiteRepository, assets: EncryptedAssetStore, maximumImageBytes: Int = PasteboardLimits().maximumImageBytes, thumbnailPixels: Int = 96) {
        self.repository = repository
        self.assets = assets
        self.maximumImageBytes = maximumImageBytes
        self.thumbnailPixels = max(32, min(thumbnailPixels, 320))
    }

    public func image(eventID: ClipboardEventID) async throws -> ClipboardImageContent? {
        guard let representation = try await imageRepresentation(eventID: eventID),
              let opaqueName = representation.encryptedPayloadReference,
              representation.byteSize <= maximumImageBytes else { return nil }
        let reference = EncryptedAssetReference(opaqueName: opaqueName, encryptedBytes: representation.byteSize)
        let original = try await assets.load(reference, maximumBytes: maximumImageBytes)
        guard let source = CGImageSourceCreateWithData(original as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = Self.thumbnail(source: source, maximumPixels: thumbnailPixels) else { throw AssetStoreError.malformed }
        let sourceType = CGImageSourceGetType(source) as String?
        let format: ClipboardImageFormat = sourceType == UTType.tiff.identifier ? .tiff : .png
        return .init(originalData: original, thumbnailData: thumbnail, format: format)
    }

    /// Loads the small encrypted thumbnail persisted for current records. Legacy records fall back to
    /// generating one only when their original is itself modestly sized, preventing repeated 25 MB
    /// decryptions while keeping older clipboard history usable.
    public func thumbnail(eventID: ClipboardEventID, maximumBytes: Int = 1 * 1024 * 1024) async throws -> Data? {
        guard let representation = try await imageRepresentation(eventID: eventID) else { return nil }
        if let opaqueName = representation.encryptedThumbnailReference {
            return try await assets.load(.init(opaqueName: opaqueName, encryptedBytes: 0), maximumBytes: maximumBytes)
        }
        let legacyMaximum = min(maximumBytes * 4, maximumImageBytes)
        guard representation.byteSize <= legacyMaximum,
              let opaqueName = representation.encryptedPayloadReference else { return nil }
        let original = try await assets.load(.init(opaqueName: opaqueName, encryptedBytes: representation.byteSize), maximumBytes: legacyMaximum)
        guard let source = CGImageSourceCreateWithData(original as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return Self.thumbnail(source: source, maximumPixels: thumbnailPixels)
    }

    private func imageRepresentation(eventID: ClipboardEventID) async throws -> ClipboardRepresentation? {
        try await repository.clipboardEvents()
            .first(where: { $0.event.id == eventID })?
            .event.representations.first(where: { $0.contentType == .image })
    }

    private static func thumbnail(source: CGImageSource, maximumPixels: Int) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

public protocol PasteboardSnapshotSource: Sendable {
    func changeCount() -> Int
    func accessState() -> PasteboardAccessState
    func isKoruOriginatedChange() -> Bool
    func materialize(limits: PasteboardLimits) throws -> [[MaterializedPasteboardItem]]
}

public extension PasteboardSnapshotSource {
    func isKoruOriginatedChange() -> Bool { false }
}

public final class GeneralPasteboardSource: PasteboardSnapshotSource, @unchecked Sendable {
    private let pasteboard: NSPasteboard
    public init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }
    public func changeCount() -> Int { pasteboard.changeCount }
    public func accessState() -> PasteboardAccessState {
        if #available(macOS 15.4, *) {
            switch pasteboard.accessBehavior {
            case .alwaysDeny: return .denied
            case .alwaysAllow, .ask, .default: return .available
            @unknown default: return .unavailable
            }
        }
        return .available
    }

    public func isKoruOriginatedChange() -> Bool {
        (pasteboard.pasteboardItems ?? []).contains { item in
            item.types.contains(KoruPasteboardOrigin.type)
                && item.string(forType: KoruPasteboardOrigin.type) == KoruPasteboardOrigin.value
        }
    }

    public func materialize(limits: PasteboardLimits) throws -> [[MaterializedPasteboardItem]] {
        guard accessState() == .available else { throw PasteboardDecodeError.denied }
        let items = pasteboard.pasteboardItems ?? []
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
        if source.isKoruOriginatedChange() { return nil }
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
                let thumbnailReference: EncryptedAssetReference?
                if item.contentType == .image {
                    let stored = try await assets.storeImage(data, maximumBytes: policy.maximumImageBytes)
                    reference = stored.asset; thumbnailReference = stored.thumbnail
                } else {
                    reference = try await assets.store(data); thumbnailReference = nil
                }
                if [.plainText, .url].contains(item.contentType), let text = String(data: data, encoding: .utf8) { searchable.append(text) }
                representations.append(.init(contentType: item.contentType, encryptedPayloadReference: reference.opaqueName, encryptedThumbnailReference: thumbnailReference?.opaqueName, thumbnailByteSize: thumbnailReference?.encryptedBytes, displayMetadata: item.displayMetadata, byteSize: data.count))
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

public enum ClipboardRecallError: Error, Equatable, Sendable { case unavailable; case missingFile; case unsupportedTarget }
public struct ClipboardRecallSession: Hashable, Sendable {
    public var originalCommandSpan: Range<Int>?
    public var focusedQuery: String
    public var results: [SearchResult]
}

public actor ClipboardRecallService {
    private let search: InMemorySearchIndex
    public init(search: InMemorySearchIndex) { self.search = search }
    public func typedCLP(commandSpan: Range<Int>) -> ClipboardRecallSession { .init(originalCommandSpan: commandSpan, focusedQuery: "", results: []) }
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
    public func saveToLibrary(eventID: ClipboardEventID, tags: [String]) async throws -> SavedItem {
        guard let payload = try await repository.clipboardEvents().first(where: { $0.event.id == eventID }), let content = payload.searchableText else { throw ClipboardRecallError.unavailable }
        let item = try SavedItemValidation.preparedForSave(
            SavedItem(title: "", behavior: .savedText, plainContent: content, tags: tags)
        )
        try await repository.save(item); await search.upsert(item); return item
    }
}
