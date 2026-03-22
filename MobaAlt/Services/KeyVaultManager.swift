// KeyVaultManager.swift
//
// AES-256-GCM encrypted SSH key vault.
//
// Vault layout in ~/Library/Application Support/MobaAlt/:
//   keyvault.enc  — AES-GCM combined (nonce + ciphertext + tag) of JSON [String: Data]
//   keyvault.salt — 32 random bytes generated once; NOT secret; persisted alongside vault
//
// Key derivation:
//   HKDF<SHA256>(inputKeyMaterial: password.utf8, salt: persistedSalt) -> SymmetricKey(256-bit)
//
// Wrong-password detection: AES.GCM.open throws CryptoKitError on tag mismatch → VaultError.wrongPassword

import Foundation
import CryptoKit

// MARK: - Errors

enum VaultError: Error, Equatable {
    case locked
    case wrongPassword
    case vaultCorrupted
    case keyNotFound(String)
}

// MARK: - KeyVaultManager

actor KeyVaultManager {

    // MARK: Static

    /// Default vault directory (~/Library/Application Support/MobaAlt/)
    static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MobaAlt", isDirectory: true)
    }

    // MARK: Properties

    private let directory: URL
    private var derivedKey: SymmetricKey?
    private var keyStore: [String: Data] = [:]

    private var vaultURL: URL { directory.appendingPathComponent("keyvault.enc") }
    private var saltURL: URL  { directory.appendingPathComponent("keyvault.salt") }

    // MARK: Initializers

    /// Designated initializer — uses the provided directory (for test isolation).
    init(directory: URL) {
        self.directory = directory
    }

    /// Convenience initializer for production use.
    init() {
        self.directory = KeyVaultManager.defaultDirectory
    }

    // MARK: Public API

    /// Returns true if the vault has been successfully unlocked.
    var isUnlocked: Bool {
        derivedKey != nil
    }

    /// Unlocks the vault using the given master password.
    /// - Throws: `VaultError.wrongPassword` if decryption fails with the given password.
    func unlock(masterPassword: String) throws {
        // Ensure directory exists
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 1. Load or generate salt
        let salt = try loadOrCreateSalt()

        // 2. Derive key from master password + salt
        let key = deriveKey(masterPassword: masterPassword, salt: salt)

        // 3. Load and decrypt vault, or create empty vault
        if FileManager.default.fileExists(atPath: vaultURL.path) {
            let encryptedData = try Data(contentsOf: vaultURL)
            let store = try decrypt(data: encryptedData, using: key)
            self.keyStore = store
        } else {
            // New vault — write encrypted empty dictionary
            self.keyStore = [:]
            let encrypted = try encrypt(store: [:], using: key)
            try encrypted.write(to: vaultURL, options: .atomic)
        }

        self.derivedKey = key
    }

    /// Adds or replaces an SSH private key entry in the vault.
    /// - Throws: `VaultError.locked` if the vault has not been unlocked.
    func addKey(name: String, privateKeyData: Data) throws {
        guard let key = derivedKey else { throw VaultError.locked }
        keyStore[name] = privateKeyData
        try persist(using: key)
    }

    /// Retrieves an SSH private key entry from the vault.
    /// - Throws: `VaultError.locked` if the vault has not been unlocked.
    /// - Throws: `VaultError.keyNotFound(name)` if no entry exists with the given name.
    func getKey(name: String) throws -> Data {
        guard derivedKey != nil else { throw VaultError.locked }
        guard let data = keyStore[name] else { throw VaultError.keyNotFound(name) }
        return data
    }

    /// Removes an SSH private key entry from the vault.
    /// - Throws: `VaultError.locked` if the vault has not been unlocked.
    /// - Throws: `VaultError.keyNotFound(name)` if no entry exists with the given name.
    func removeKey(name: String) throws {
        guard let key = derivedKey else { throw VaultError.locked }
        guard keyStore[name] != nil else { throw VaultError.keyNotFound(name) }
        keyStore.removeValue(forKey: name)
        try persist(using: key)
    }

    /// Returns the names of all stored SSH key entries.
    /// - Throws: `VaultError.locked` if the vault has not been unlocked.
    func listKeyNames() throws -> [String] {
        guard derivedKey != nil else { throw VaultError.locked }
        return Array(keyStore.keys)
    }

    // MARK: Private — Key Derivation

    private func deriveKey(masterPassword: String, salt: Data) -> SymmetricKey {
        let inputKeyMaterial = SymmetricKey(data: Data(masterPassword.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            outputByteCount: 32
        )
    }

    // MARK: Private — Salt Management

    private func loadOrCreateSalt() throws -> Data {
        if FileManager.default.fileExists(atPath: saltURL.path) {
            return try Data(contentsOf: saltURL)
        }
        // Generate and persist 32 random bytes
        var saltBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard status == errSecSuccess else {
            throw VaultError.vaultCorrupted
        }
        let saltData = Data(saltBytes)
        try saltData.write(to: saltURL, options: .atomic)
        return saltData
    }

    // MARK: Private — Encryption / Decryption

    private func encrypt(store: [String: Data], using key: SymmetricKey) throws -> Data {
        let jsonData = try JSONEncoder().encode(store)
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        guard let combined = sealedBox.combined else {
            throw VaultError.vaultCorrupted
        }
        return combined
    }

    private func decrypt(data: Data, using key: SymmetricKey) throws -> [String: Data] {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return try JSONDecoder().decode([String: Data].self, from: decrypted)
        } catch is CryptoKitError {
            throw VaultError.wrongPassword
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.vaultCorrupted
        }
    }

    // MARK: Private — Persistence

    private func persist(using key: SymmetricKey) throws {
        let encrypted = try encrypt(store: keyStore, using: key)
        try encrypted.write(to: vaultURL, options: .atomic)
    }
}
