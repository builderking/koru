import Foundation
import KoruDomain

public protocol VaultIntegrationStopper: Sendable { func stopForVaultReset() async }
public struct NoopVaultIntegrationStopper: VaultIntegrationStopper { public init() {}; public func stopForVaultReset() async {} }

public struct MaintenanceReport: Hashable, Sendable {
    public let integrityOK: Bool
    public let expiredClipboardCount: Int
    public let purgedSavedItemCount: Int
    public let orphanAssetCount: Int
}

public actor VaultMaintenanceService {
    private let repository: EncryptedSQLiteRepository
    private let assets: EncryptedAssetStore
    private let keys: VaultKeyManager
    private let search: InMemorySearchIndex
    private let stopper: any VaultIntegrationStopper
    private var resetting = false
    public init(repository: EncryptedSQLiteRepository, assets: EncryptedAssetStore, keys: VaultKeyManager, search: InMemorySearchIndex, stopper: any VaultIntegrationStopper = NoopVaultIntegrationStopper()) {
        self.repository = repository; self.assets = assets; self.keys = keys; self.search = search; self.stopper = stopper
    }

    public func run(policy: RetentionPolicy, recoveryWindow: TimeInterval = 30 * 24 * 60 * 60, backupLimit: Int = 3, now: Date = .now) async throws -> MaintenanceReport {
        guard !resetting else { throw RepositoryError.unavailable }
        let integrity = try await repository.integrityCheck()
        let expired = try await repository.applyRetention(policy, now: now)
        for id in expired { await search.remove(clipboardEventID: id) }
        let purged = try await repository.purgeRecentlyDeleted(before: now.addingTimeInterval(-recoveryWindow))
        for id in purged { await search.remove(savedItemID: id) }
        let clipboard = try await repository.clipboardEvents()
        let owned = Set(clipboard.flatMap { $0.event.representations.compactMap(\.encryptedPayloadReference) })
        let orphanCount = try await assets.removeOrphans(ownedNames: owned)
        try await repository.pruneBackups(keeping: backupLimit)
        return .init(integrityOK: integrity, expiredClipboardCount: expired.count, purgedSavedItemCount: purged.count, orphanAssetCount: orphanCount)
    }

    public func resetVault(confirmed: Bool) async throws {
        guard confirmed, !resetting else { throw RepositoryError.unavailable }
        resetting = true
        defer { resetting = false }
        await stopper.stopForVaultReset()
        await search.purge()
        await keys.purgeSession()
        try await keys.removeKey()
        try await repository.destroyFiles()
        try await assets.removeAll()
    }
}
