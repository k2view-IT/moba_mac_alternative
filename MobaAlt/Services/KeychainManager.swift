// KeychainManager.swift
//
// Thread-safe actor wrapping Security.framework SecItem* APIs.
// Stores SSH session passwords in the macOS Keychain keyed by session UUID.
//
// Service identifier: "com.mobaalt.MobaAlt" (production)
// Tests use an isolated service: "com.mobaalt.MobaAlt.tests"

import Foundation
import Security

// MARK: - Errors

enum KeychainError: Error, Equatable {
    case operationFailed(OSStatus)
    case dataConversionFailed
}

// MARK: - KeychainManager

actor KeychainManager {

    // MARK: Properties

    private let service: String

    // MARK: Initializers

    /// Production initializer — uses the default service identifier.
    init() {
        self.service = "com.mobaalt.MobaAlt"
    }

    /// Designated initializer for test isolation.
    /// - Parameter service: A unique service string to isolate test keychain items.
    init(service: String) {
        self.service = service
    }

    // MARK: Public API

    /// Saves (or overwrites) the password for the given session ID.
    func savePassword(_ password: String, for sessionId: UUID) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: sessionId.uuidString,
        ]

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: sessionId.uuidString,
            kSecValueData: passwordData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try updatePassword(passwordData: passwordData, query: query)
        } else if status != errSecSuccess {
            throw KeychainError.operationFailed(status)
        }
    }

    /// Retrieves the stored password for the given session ID.
    /// Returns nil if no item is found.
    func getPassword(for sessionId: UUID) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: sessionId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        return password
    }

    /// Deletes the stored password for the given session ID.
    /// Idempotent — does not throw if the item does not exist.
    func deletePassword(for sessionId: UUID) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: sessionId.uuidString,
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.operationFailed(status)
        }
    }

    // MARK: Private

    /// Updates an existing keychain item. Called by savePassword on errSecDuplicateItem.
    private func updatePassword(passwordData: Data, query: [CFString: Any]) throws {
        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: passwordData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(status)
        }
    }
}
