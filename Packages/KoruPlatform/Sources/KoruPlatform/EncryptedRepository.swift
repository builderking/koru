import CryptoKit
import Foundation
import KoruDomain
import SQLite3

public enum RepositoryError: Error, Equatable, Sendable {
    case unavailable
    case sqlite(Int32)
    case corrupt
    case migrationFailed
    case invalidRecord
}

public actor EncryptedSQLiteRepository: SavedItemRepository {
    public static let schemaVersion = 1
    private let databaseURL: URL
    private let backupDirectory: URL
    private let keyManager: VaultKeyManager
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(databaseURL: URL, backupDirectory: URL, keyManager: VaultKeyManager) {
        self.databaseURL = databaseURL; self.backupDirectory = backupDirectory; self.keyManager = keyManager
        encoder.outputFormatting = [.sortedKeys]
    }

    public func open() async throws {
        guard db == nil else { return }
        let exists = FileManager.default.fileExists(atPath: databaseURL.path)
        try await keyManager.beginSession(vaultExists: exists)
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: databaseURL.deletingLastPathComponent().path)
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK, let handle else { throw RepositoryError.unavailable }
        db = handle
        do {
            try execute("PRAGMA foreign_keys=ON")
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA secure_delete=ON")
            try execute("PRAGMA temp_store=MEMORY")
            let version = try scalarInt("PRAGMA user_version")
            if version > Self.schemaVersion { throw RepositoryError.migrationFailed }
            if version < Self.schemaVersion {
                if exists { try createEncryptedBackup() }
                try transaction {
                    try execute("CREATE TABLE IF NOT EXISTS records (id TEXT PRIMARY KEY, kind INTEGER NOT NULL, state INTEGER NOT NULL, created REAL NOT NULL, updated REAL NOT NULL, expires REAL, byte_count INTEGER NOT NULL, ciphertext BLOB NOT NULL)")
                    try execute("CREATE INDEX IF NOT EXISTS records_kind_state ON records(kind,state)")
                    try execute("PRAGMA user_version=\(Self.schemaVersion)")
                }
            }
            guard try integrityCheck() else { throw RepositoryError.corrupt }
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databaseURL.path)
        } catch {
            sqlite3_close_v2(handle); db = nil
            await keyManager.purgeSession()
            throw error
        }
    }

    public func close() async {
        if let db { sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil); sqlite3_close_v2(db) }
        db = nil
        await keyManager.purgeSession()
    }

    public func save(_ item: SavedItem) async throws { try await save(item, lifecycle: item.archivedAt == nil ? .active : .archived) }

    public func save(_ item: SavedItem, lifecycle: SavedItemLifecycle) async throws {
        let plaintext = try encoder.encode(item)
        let id = item.id.description
        let metadata = aad(id: id, kind: 1, state: lifecycleCode(lifecycle), created: item.createdAt.timeIntervalSince1970)
        let ciphertext = try await keyManager.withKey { try VaultCipher.seal(plaintext, using: $0, authenticating: metadata) }
        try withStatement("INSERT INTO records(id,kind,state,created,updated,expires,byte_count,ciphertext) VALUES(?,1,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET state=excluded.state,updated=excluded.updated,byte_count=excluded.byte_count,ciphertext=excluded.ciphertext") { statement in
            bindText(statement, 1, id); bindInt(statement, 2, lifecycleCode(lifecycle)); bindDouble(statement, 3, item.createdAt.timeIntervalSince1970)
            bindDouble(statement, 4, item.updatedAt.timeIntervalSince1970); sqlite3_bind_null(statement, 5); bindInt(statement, 6, ciphertext.count); bindBlob(statement, 7, ciphertext)
            try stepDone(statement)
        }
    }

    public func item(id: SavedItemID) async throws -> SavedItem? {
        guard let row = try record(id: id.description, kind: 1) else { return nil }
        return try await decrypt(row, as: SavedItem.self)
    }

    public func savedItems(states: Set<SavedItemLifecycle> = [.active]) async throws -> [SavedItem] {
        let rows = try records(kind: 1).filter { states.contains(lifecycle($0.state)) }
        var result: [SavedItem] = []
        for row in rows { result.append(try await decrypt(row, as: SavedItem.self)) }
        return result
    }

    public func setLifecycle(id: SavedItemID, _ lifecycle: SavedItemLifecycle, at date: Date = .now) async throws {
        guard var item = try await item(id: id) else { return }
        item.updatedAt = date
        item.archivedAt = lifecycle == .archived ? date : nil
        try await save(item, lifecycle: lifecycle)
    }

    public func permanentlyPurgeSavedItem(id: SavedItemID) throws {
        try delete(id: id.description, kind: 1)
    }

    public func purgeRecentlyDeleted(before cutoff: Date) throws -> [SavedItemID] {
        let rows = try records(kind: 1).filter { $0.state == 2 && $0.updated < cutoff.timeIntervalSince1970 }
        for row in rows { try delete(id: row.id, kind: 1) }
        return rows.compactMap { UUID(uuidString: $0.id).map(SavedItemID.init) }
    }

    public func saveClipboard(_ payload: ClipboardPayload) async throws {
        let plaintext = try encoder.encode(payload)
        let event = payload.event
        let id = event.id.description
        let metadata = aad(id: id, kind: 2, state: 0, created: event.capturedAt.timeIntervalSince1970)
        let ciphertext = try await keyManager.withKey { try VaultCipher.seal(plaintext, using: $0, authenticating: metadata) }
        try withStatement("INSERT OR REPLACE INTO records(id,kind,state,created,updated,expires,byte_count,ciphertext) VALUES(?,2,0,?,?,?,?,?)") { statement in
            bindText(statement, 1, id); bindDouble(statement, 2, event.capturedAt.timeIntervalSince1970); bindDouble(statement, 3, event.capturedAt.timeIntervalSince1970)
            bindDouble(statement, 4, event.expiresAt.timeIntervalSince1970); bindInt(statement, 5, ciphertext.count); bindBlob(statement, 6, ciphertext); try stepDone(statement)
        }
    }

    public func clipboardEvents() async throws -> [ClipboardPayload] {
        var result: [ClipboardPayload] = []
        for row in try records(kind: 2) { result.append(try await decrypt(row, as: ClipboardPayload.self)) }
        return result
    }

    struct StoredRecallSignal: Codable, Sendable {
        let id: UUID; let query: String; let itemID: UUID; let appBundleID: String?; let selectionCount: Int; let lastSelectedAt: Date
    }
    func recallSignals() async throws -> [StoredRecallSignal] {
        var result: [StoredRecallSignal] = []
        for row in try records(kind: 3) { result.append(try await decrypt(row, as: StoredRecallSignal.self)) }
        return result
    }
    func saveRecallSignal(_ signal: StoredRecallSignal) async throws {
        let plaintext = try encoder.encode(signal); let id = signal.id.uuidString; let created = signal.lastSelectedAt.timeIntervalSince1970
        let metadata = aad(id: id, kind: 3, state: 0, created: created)
        let ciphertext = try await keyManager.withKey { try VaultCipher.seal(plaintext, using: $0, authenticating: metadata) }
        try withStatement("INSERT OR REPLACE INTO records(id,kind,state,created,updated,expires,byte_count,ciphertext) VALUES(?,3,0,?,?,?,?,?)") { s in
            bindText(s, 1, id); bindDouble(s, 2, created); bindDouble(s, 3, created); sqlite3_bind_null(s, 4); bindInt(s, 5, ciphertext.count); bindBlob(s, 6, ciphertext); try stepDone(s)
        }
    }
    public func resetRecallSignals() throws { try execute("DELETE FROM records WHERE kind=3") }

    public func clearClipboard() throws { try execute("DELETE FROM records WHERE kind=2") }
    public func storageSummary() throws -> ClipboardStorageSummary {
        var count = 0, bytes = 0
        try withStatement("SELECT COUNT(*), COALESCE(SUM(byte_count),0) FROM records WHERE kind=2") { s in
            guard sqlite3_step(s) == SQLITE_ROW else { throw RepositoryError.sqlite(sqlite3_errcode(db)) }
            count = Int(sqlite3_column_int64(s, 0)); bytes = Int(sqlite3_column_int64(s, 1))
        }
        return .init(retainedCount: count, encryptedBytes: bytes)
    }

    public func applyRetention(_ policy: RetentionPolicy, now: Date = .now) throws -> [ClipboardEventID] {
        var removed: [ClipboardEventID] = []
        try transaction {
            let rows = try records(kind: 2).sorted { $0.created > $1.created }
            var keptBytes = 0
            for (index, row) in rows.enumerated() {
                let expired = (row.expires ?? 0) <= now.timeIntervalSince1970 || now.timeIntervalSince1970 - row.created > policy.maximumAge
                let over = index >= policy.maximumEvents || keptBytes + row.byteCount > policy.maximumAssetBytes
                if !policy.clipboardHistoryEnabled || expired || over {
                    try delete(id: row.id, kind: 2)
                    if let uuid = UUID(uuidString: row.id) { removed.append(.init(uuid)) }
                } else { keptBytes += row.byteCount }
            }
        }
        return removed
    }

    public func integrityCheck() throws -> Bool {
        var result = ""
        try withStatement("PRAGMA integrity_check") { s in
            guard sqlite3_step(s) == SQLITE_ROW, let p = sqlite3_column_text(s, 0) else { throw RepositoryError.corrupt }
            result = String(cString: p)
        }
        return result == "ok"
    }

    // Internal fault hooks are intentionally unavailable to app clients and exercise real SQLite failure paths.
    func setMaximumPageCountForTesting(_ pages: Int) throws { try execute("PRAGMA max_page_count=\(pages)") }
    func setSchemaVersionForTesting(_ version: Int) throws { try execute("PRAGMA user_version=\(version)") }

    public func createEncryptedBackup() throws {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return }
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let target = backupDirectory.appendingPathComponent("vault-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).sqlite")
        guard let db else { throw RepositoryError.unavailable }
        var destination: OpaquePointer?
        guard sqlite3_open_v2(target.path, &destination, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let destination else { throw RepositoryError.unavailable }
        defer { sqlite3_close_v2(destination) }
        guard let backup = sqlite3_backup_init(destination, "main", db, "main") else { throw RepositoryError.sqlite(sqlite3_errcode(destination)) }
        defer { sqlite3_backup_finish(backup) }
        guard sqlite3_backup_step(backup, -1) == SQLITE_DONE else { throw RepositoryError.sqlite(sqlite3_errcode(destination)) }
    }

    public func pruneBackups(keeping maximum: Int) throws {
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey]).sorted {
            (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast > (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        for file in files.dropFirst(max(0, maximum)) { try FileManager.default.removeItem(at: file) }
    }

    public func destroyFiles() async throws {
        await close()
        for url in [databaseURL, URL(fileURLWithPath: databaseURL.path + "-wal"), URL(fileURLWithPath: databaseURL.path + "-shm"), backupDirectory] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private struct Row: Sendable { let id: String; let kind: Int; let state: Int; let created: Double; let updated: Double; let expires: Double?; let byteCount: Int; let ciphertext: Data }
    private func decrypt<T: Decodable>(_ row: Row, as: T.Type) async throws -> T {
        let metadata = aad(id: row.id, kind: row.kind, state: row.state, created: row.created)
        let data = try await keyManager.withKey { try VaultCipher.open(row.ciphertext, using: $0, authenticating: metadata) }
        return try decoder.decode(T.self, from: data)
    }
    private func aad(id: String, kind: Int, state: Int, created: Double) -> Data { Data("koru:v1:\(id):\(kind):\(state):\(created)".utf8) }
    private func lifecycleCode(_ value: SavedItemLifecycle) -> Int { switch value { case .active: 0; case .archived: 1; case .recentlyDeleted: 2 } }
    private func lifecycle(_ value: Int) -> SavedItemLifecycle { value == 1 ? .archived : value == 2 ? .recentlyDeleted : .active }
    private func record(id: String, kind: Int) throws -> Row? { try records(kind: kind).first { $0.id == id } }
    private func records(kind: Int) throws -> [Row] {
        var result: [Row] = []
        try withStatement("SELECT id,kind,state,created,updated,expires,byte_count,ciphertext FROM records WHERE kind=?") { s in
            bindInt(s, 1, kind)
            while sqlite3_step(s) == SQLITE_ROW {
                guard let idp = sqlite3_column_text(s, 0), let blob = sqlite3_column_blob(s, 7) else { throw RepositoryError.invalidRecord }
                let size = Int(sqlite3_column_bytes(s, 7)); let expires = sqlite3_column_type(s, 5) == SQLITE_NULL ? nil : sqlite3_column_double(s, 5)
                result.append(Row(id: String(cString: idp), kind: Int(sqlite3_column_int(s, 1)), state: Int(sqlite3_column_int(s, 2)), created: sqlite3_column_double(s, 3), updated: sqlite3_column_double(s, 4), expires: expires, byteCount: Int(sqlite3_column_int64(s, 6)), ciphertext: Data(bytes: blob, count: size)))
            }
        }
        return result
    }
    private func transaction(_ body: () throws -> Void) throws { try execute("BEGIN IMMEDIATE"); do { try body(); try execute("COMMIT") } catch { try? execute("ROLLBACK"); throw error } }
    private func delete(id: String, kind: Int) throws { try withStatement("DELETE FROM records WHERE id=? AND kind=?") { bindText($0, 1, id); bindInt($0, 2, kind); try stepDone($0) } }
    private func execute(_ sql: String) throws { guard let db, sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw RepositoryError.sqlite(sqlite3_errcode(db)) } }
    private func scalarInt(_ sql: String) throws -> Int { var value = 0; try withStatement(sql) { guard sqlite3_step($0) == SQLITE_ROW else { throw RepositoryError.sqlite(sqlite3_errcode(db)) }; value = Int(sqlite3_column_int($0, 0)) }; return value }
    private func withStatement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws { guard let db else { throw RepositoryError.unavailable }; var s: OpaquePointer?; guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK, let s else { throw RepositoryError.sqlite(sqlite3_errcode(db)) }; defer { sqlite3_finalize(s) }; try body(s) }
    private func stepDone(_ s: OpaquePointer) throws { guard sqlite3_step(s) == SQLITE_DONE else { throw RepositoryError.sqlite(sqlite3_errcode(db)) } }
    private func bindText(_ s: OpaquePointer, _ i: Int32, _ value: String) { sqlite3_bind_text(s, i, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    private func bindInt(_ s: OpaquePointer, _ i: Int32, _ value: Int) { sqlite3_bind_int64(s, i, sqlite3_int64(value)) }
    private func bindDouble(_ s: OpaquePointer, _ i: Int32, _ value: Double) { sqlite3_bind_double(s, i, value) }
    private func bindBlob(_ s: OpaquePointer, _ i: Int32, _ value: Data) { _ = value.withUnsafeBytes { sqlite3_bind_blob(s, i, $0.baseAddress, Int32(value.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) } }
}
