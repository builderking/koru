import CryptoKit
import Foundation
import KoruDomain
import Security

public enum VaultKeyError: Error, Equatable, Sendable {
    case sessionUnavailable
    case keyMissingForExistingVault
    case keychainFailure(Int32)
    case invalidKey
}

public protocol VaultKeyStore: Sendable {
    func read(service: String, account: String) throws -> Data?
    func write(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

public struct DataProtectionKeychainStore: VaultKeyStore {
    public init() {}

    public func read(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultKeyError.keychainFailure(status) }
        return result as? Data
    }

    public func write(_ data: Data, service: String, account: String) throws {
        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultKeyError.keychainFailure(status) }
    }

    public func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultKeyError.keychainFailure(status)
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}

public actor VaultKeyManager {
    public enum SessionState: Sendable { case unavailable, usable }
    private let store: any VaultKeyStore
    private let service: String
    private let account: String
    private var key: SymmetricKey?
    private var state: SessionState = .unavailable

    public init(store: any VaultKeyStore = DataProtectionKeychainStore(), service: String = "io.builderking.koru.vault", account: String = "master-v1") {
        self.store = store; self.service = service; self.account = account
    }

    public func beginSession(vaultExists: Bool) throws {
        let stored = try store.read(service: service, account: account)
        if let stored {
            guard stored.count == 32 else { throw VaultKeyError.invalidKey }
            key = SymmetricKey(data: stored)
        } else if vaultExists {
            throw VaultKeyError.keyMissingForExistingVault
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw VaultKeyError.keychainFailure(errSecAllocate)
            }
            let data = Data(bytes)
            try store.write(data, service: service, account: account)
            key = SymmetricKey(data: data)
            bytes.resetBytes(in: 0..<bytes.count)
        }
        state = .usable
    }

    public func withKey<T: Sendable>(_ body: @Sendable (SymmetricKey) throws -> T) throws -> T {
        guard state == .usable, let key else { throw VaultKeyError.sessionUnavailable }
        return try body(key)
    }

    public func purgeSession() { key = nil; state = .unavailable }

    public func removeKey() throws {
        purgeSession()
        try store.delete(service: service, account: account)
    }

    public func sessionState() -> SessionState { state }
}

public enum VaultCipher {
    public static func seal(_ plaintext: Data, using key: SymmetricKey, authenticating metadata: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: metadata)
        guard let combined = box.combined else { throw VaultKeyError.invalidKey }
        return combined
    }

    public static func open(_ ciphertext: Data, using key: SymmetricKey, authenticating metadata: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: ciphertext), using: key, authenticating: metadata)
    }

    public static func keyedDigest(_ data: Data, using key: SymmetricKey) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }
}
