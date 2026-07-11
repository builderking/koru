import AppKit
import CryptoKit
import Foundation
import ImageIO

public enum AssetStoreError: Error, Equatable, Sendable { case oversized; case malformed; case missing; case unsupported }

public struct EncryptedAssetReference: Hashable, Codable, Sendable {
    public let opaqueName: String
    public let encryptedBytes: Int
    public init(opaqueName: String, encryptedBytes: Int) { self.opaqueName = opaqueName; self.encryptedBytes = encryptedBytes }
}

public actor EncryptedAssetStore {
    private let directory: URL
    private let keyManager: VaultKeyManager
    private let maximumAllocation: Int
    public init(directory: URL, keyManager: VaultKeyManager, maximumAllocation: Int = 25 * 1024 * 1024) {
        self.directory = directory; self.keyManager = keyManager; self.maximumAllocation = maximumAllocation
    }

    public func storeImage(_ data: Data, maximumBytes: Int, maximumPixels: Int = 40_000_000) async throws -> (asset: EncryptedAssetReference, thumbnail: EncryptedAssetReference?) {
        guard data.count <= min(maximumBytes, maximumAllocation) else { throw AssetStoreError.oversized }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw AssetStoreError.malformed }
        guard width <= maximumPixels, height <= maximumPixels, width.multipliedReportingOverflow(by: height).overflow == false, width * height <= maximumPixels else { throw AssetStoreError.oversized }
        let asset = try await store(data)
        let thumbnail: EncryptedAssetReference?
        if let data = try makeThumbnail(source) { thumbnail = try await store(data) } else { thumbnail = nil }
        return (asset, thumbnail)
    }

    public func store(_ data: Data) async throws -> EncryptedAssetReference {
        guard data.count <= maximumAllocation else { throw AssetStoreError.oversized }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let name = UUID().uuidString.lowercased()
        let aad = Data("koru-asset:v1:\(name)".utf8)
        let sealed = try await keyManager.withKey { try VaultCipher.seal(data, using: $0, authenticating: aad) }
        try sealed.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: directory.appendingPathComponent(name).path)
        return .init(opaqueName: name, encryptedBytes: sealed.count)
    }

    public func load(_ reference: EncryptedAssetReference, maximumBytes: Int) async throws -> Data {
        let url = directory.appendingPathComponent(reference.opaqueName)
        guard FileManager.default.fileExists(atPath: url.path) else { throw AssetStoreError.missing }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= maximumBytes + 64, size <= maximumAllocation + 64 else { throw AssetStoreError.oversized }
        let ciphertext = try Data(contentsOf: url, options: [.mappedIfSafe])
        let aad = Data("koru-asset:v1:\(reference.opaqueName)".utf8)
        return try await keyManager.withKey { try VaultCipher.open(ciphertext, using: $0, authenticating: aad) }
    }

    public func remove(_ references: [EncryptedAssetReference]) throws {
        for reference in references { try? FileManager.default.removeItem(at: directory.appendingPathComponent(reference.opaqueName)) }
    }

    public func removeOrphans(ownedNames: Set<String>) throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
        var count = 0
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where !ownedNames.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url); count += 1
        }
        return count
    }

    public func removeAll() throws { if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) } }

    private func makeThumbnail(_ source: CGImageSource) throws -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 320,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw AssetStoreError.malformed }
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72])
    }
}
