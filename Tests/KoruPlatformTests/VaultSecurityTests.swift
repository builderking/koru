import CryptoKit
import Foundation
import KoruDomain
@testable import KoruPlatform
import Testing

final class MemoryKeyStore: VaultKeyStore, @unchecked Sendable {
    private let lock = NSLock(); private var value: Data?
    func read(service: String, account: String) throws -> Data? { lock.withLock { value } }
    func write(_ data: Data, service: String, account: String) throws { lock.withLock { value = data } }
    func delete(service: String, account: String) throws { lock.withLock { value = nil } }
    var snapshot: Data? { lock.withLock { value } }
}

struct TestVault {
    let root: URL; let store: MemoryKeyStore; let keys: VaultKeyManager; let repository: EncryptedSQLiteRepository; let assets: EncryptedAssetStore
    static func make() async throws -> TestVault {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("koru-test-\(UUID().uuidString)")
        let store = MemoryKeyStore(); let keys = VaultKeyManager(store: store, service: UUID().uuidString)
        let repository = EncryptedSQLiteRepository(databaseURL: root.appendingPathComponent("vault.sqlite"), backupDirectory: root.appendingPathComponent("backups"), keyManager: keys)
        let assets = EncryptedAssetStore(directory: root.appendingPathComponent("assets"), keyManager: keys)
        try await repository.open(); return .init(root: root, store: store, keys: keys, repository: repository, assets: assets)
    }
    func cleanup() async { await repository.close(); try? FileManager.default.removeItem(at: root) }
}

@Test func keyManagerCreatesExactly256BitNonReplacementKey() async throws {
    let store = MemoryKeyStore(); let manager = VaultKeyManager(store: store, service: UUID().uuidString)
    try await manager.beginSession(vaultExists: false)
    #expect(store.snapshot?.count == 32)
    await manager.purgeSession()
    await #expect(throws: VaultKeyError.sessionUnavailable) { try await manager.withKey { _ in true } }
    try await manager.removeKey()
    await #expect(throws: VaultKeyError.keyMissingForExistingVault) { try await manager.beginSession(vaultExists: true) }
    #expect(store.snapshot == nil)
}

@Test func cipherAuthenticatesMetadataAndTampering() throws {
    let key = SymmetricKey(size: .bits256), plain = Data("private fixture".utf8), aad = Data("record-a".utf8)
    var sealed = try VaultCipher.seal(plain, using: key, authenticating: aad); sealed[sealed.startIndex] ^= 1
    #expect(throws: (any Error).self) { try VaultCipher.open(sealed, using: key, authenticating: aad) }
    let valid = try VaultCipher.seal(plain, using: key, authenticating: aad)
    #expect(throws: (any Error).self) { try VaultCipher.open(valid, using: key, authenticating: Data("record-b".utf8)) }
}

@Test func repositoryCRUDLifecycleBackupAndNoPlaintextAtRest() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let marker = "KNOWN-PLAINTEXT-\(UUID().uuidString)"
    var item = SavedItem(title: marker, behavior: .savedText, plainContent: "body-\(marker)")
    try await vault.repository.save(item)
    #expect(try await vault.repository.item(id: item.id)?.title == marker)
    try await vault.repository.setLifecycle(id: item.id, .recentlyDeleted)
    #expect(try await vault.repository.savedItems(states: [.active]).isEmpty)
    #expect(try await vault.repository.items(in: .recentlyDeleted).first?.deletedAt != nil)
    try await vault.repository.setLifecycle(id: item.id, .active)
    #expect(try await vault.repository.savedItems(states: [.active]).count == 1)
    #expect(try await vault.repository.item(id: item.id)?.deletedAt == nil)
    try await vault.repository.createEncryptedBackup()
    await vault.repository.close()
    let files = (try? FileManager.default.subpathsOfDirectory(atPath: vault.root.path)) ?? []
    for file in files {
        let url = vault.root.appendingPathComponent(file); var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue, let data = try? Data(contentsOf: url) else { continue }
        #expect(!data.contains(Data(marker.utf8)), "plaintext leaked in \(file)")
    }
    try await vault.repository.open()
    item.title = "updated"; item.updatedAt = .now; try await vault.repository.save(item)
    #expect(try await vault.repository.integrityCheck())
    try await vault.repository.permanentlyPurgeSavedItem(id: item.id)
    #expect(try await vault.repository.item(id: item.id) == nil)
}

@Test func repositoryFailsClosedAfterKeyLoss() async throws {
    let vault = try await TestVault.make(); try await vault.repository.save(.init(title: "secret", behavior: .savedText, plainContent: "secret")); await vault.repository.close()
    let databaseURL = vault.root.appendingPathComponent("vault.sqlite")
    let bytesBeforeFailure = try Data(contentsOf: databaseURL)
    try await vault.keys.removeKey()
    await #expect(throws: VaultKeyError.keyMissingForExistingVault) { try await vault.repository.open() }
    #expect(vault.store.snapshot == nil)
    // A failed unlock must never mutate or destroy the encrypted vault on disk.
    #expect(try Data(contentsOf: databaseURL) == bytesBeforeFailure)
    try? FileManager.default.removeItem(at: vault.root)
}

@Test func unentitledProcessesStillPersistTheVaultKeyThroughTheKeychainFallback() throws {
    // Ad-hoc and unsigned builds (the shipped app is built with CODE_SIGNING_ALLOWED=NO) get
    // errSecMissingEntitlement from the data-protection keychain; the store must fail over to the
    // file-based keychain instead of leaving the vault permanently unopenable.
    let store = DataProtectionKeychainStore()
    let service = "io.builderking.koru.tests.\(UUID().uuidString)"
    defer { try? store.delete(service: service, account: "master-v1") }
    let key = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    try store.write(key, service: service, account: "master-v1")
    #expect(try store.read(service: service, account: "master-v1") == key)
    try store.delete(service: service, account: "master-v1")
    #expect(try store.read(service: service, account: "master-v1") == nil)
}

@Test func assetStoreRejectsOversizeAndAuthenticatesOpaqueFiles() async throws {
    let vault = try await TestVault.make(); defer { Task { await vault.cleanup() } }
    let ref = try await vault.assets.store(Data("asset secret".utf8))
    #expect(!ref.opaqueName.contains("asset"))
    #expect(try await vault.assets.load(ref, maximumBytes: 1024) == Data("asset secret".utf8))
    await #expect(throws: AssetStoreError.oversized) { try await vault.assets.store(Data(repeating: 0, count: 26 * 1024 * 1024)) }
    let url = vault.root.appendingPathComponent("assets").appendingPathComponent(ref.opaqueName)
    var bytes = try Data(contentsOf: url); bytes[0] ^= 1; try bytes.write(to: url)
    await #expect(throws: (any Error).self) { try await vault.assets.load(ref, maximumBytes: 1024) }
}

final actor StopRecorder: VaultIntegrationStopper { private(set) var stopped = false; func stopForVaultReset() async { stopped = true } }

@Test func maintenanceExpiresClipboardPrunesOrphansAndResetStopsBeforeDestroyingKey() async throws {
    let vault = try await TestVault.make(); let index = InMemorySearchIndex(); let stopper = StopRecorder()
    let orphan = try await vault.assets.store(Data("orphan".utf8)); #expect(!orphan.opaqueName.isEmpty)
    let old = Date(timeIntervalSince1970: 1_000)
    let event = ClipboardEvent(capturedAt: old, expiresAt: old, representations: [])
    try await vault.repository.saveClipboard(.init(event: event, keyedContentDigest: Data([1])))
    var policy = RetentionPolicy.v1Defaults; policy.clipboardHistoryEnabled = true
    let service = VaultMaintenanceService(repository: vault.repository, assets: vault.assets, keys: vault.keys, search: index, stopper: stopper)
    let report = try await service.run(policy: policy, now: Date(timeIntervalSince1970: 10_000_000))
    #expect(report.expiredClipboardCount == 1); #expect(report.orphanAssetCount == 1)
    try await service.resetVault(confirmed: true)
    #expect(await stopper.stopped); #expect(vault.store.snapshot == nil)
    #expect(!FileManager.default.fileExists(atPath: vault.root.appendingPathComponent("vault.sqlite").path))
}

@Test func repositoryDiskFullFutureMigrationAndCorruptionFailClosed() async throws {
    let diskFull = try await TestVault.make()
    try await diskFull.repository.setMaximumPageCountForTesting(try await currentPageCount(diskFull.repository))
    let huge = SavedItem(title: "large", behavior: .savedText, plainContent: String(repeating: "x", count: 2 * 1024 * 1024))
    await #expect(throws: (any Error).self) { try await diskFull.repository.save(huge) }
    #expect(try await diskFull.repository.savedItems(states: [.active]).isEmpty)
    await diskFull.cleanup()

    let future = try await TestVault.make(); try await future.repository.setSchemaVersionForTesting(999); await future.repository.close()
    await #expect(throws: RepositoryError.migrationFailed) { try await future.repository.open() }
    try? FileManager.default.removeItem(at: future.root)

    let corrupt = try await TestVault.make(); try await corrupt.repository.save(.init(title: "safe", behavior: .savedText, plainContent: "safe")); await corrupt.repository.close()
    try Data(repeating: 0xFF, count: 512).write(to: corrupt.root.appendingPathComponent("vault.sqlite"))
    await #expect(throws: (any Error).self) { try await corrupt.repository.open() }
    // Detecting corruption must fail closed without destroying the store the user could still recover.
    #expect(try Data(contentsOf: corrupt.root.appendingPathComponent("vault.sqlite")) == Data(repeating: 0xFF, count: 512))
    try? FileManager.default.removeItem(at: corrupt.root)
}

private func currentPageCount(_ repository: EncryptedSQLiteRepository) async throws -> Int {
    // A freshly migrated store uses at least three pages; this bound forces the next large transaction through SQLITE_FULL.
    3
}
