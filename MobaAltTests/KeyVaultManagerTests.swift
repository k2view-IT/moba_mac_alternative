// KeyVaultManagerTests.swift
//
// Unit tests for AES-256-GCM encrypted SSH key vault.
// Each test uses an isolated temporary directory to avoid cross-test pollution.

import Testing
import Foundation
@testable import MobaAlt

struct KeyVaultManagerTests {

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Tests

    @Test func testUnlockWithCorrectPassword() async throws {
        let dir = try makeTempDirectory()
        let vault = KeyVaultManager(directory: dir)
        try await vault.unlock(masterPassword: "correct-password")
        let unlocked = await vault.isUnlocked
        #expect(unlocked == true)
    }

    @Test func testUnlockWithWrongPasswordThrows() async throws {
        let dir = try makeTempDirectory()

        // First: create vault and add a key so keyvault.enc exists
        let vault1 = KeyVaultManager(directory: dir)
        try await vault1.unlock(masterPassword: "correct-password")
        try await vault1.addKey(name: "testkey", privateKeyData: Data("key-material".utf8))

        // Second: new instance pointing at same dir, unlock with wrong password
        let vault2 = KeyVaultManager(directory: dir)
        do {
            try await vault2.unlock(masterPassword: "wrong-password")
            Issue.record("Expected VaultError.wrongPassword but no error was thrown")
        } catch VaultError.wrongPassword {
            // Expected
        } catch {
            Issue.record("Expected VaultError.wrongPassword but got: \(error)")
        }
    }

    @Test func testAddAndGetKey() async throws {
        let dir = try makeTempDirectory()
        let vault = KeyVaultManager(directory: dir)
        try await vault.unlock(masterPassword: "test-password")

        let keyData = Data("ssh-rsa-private-key-bytes".utf8)
        try await vault.addKey(name: "mykey", privateKeyData: keyData)
        let retrieved = try await vault.getKey(name: "mykey")
        #expect(retrieved == keyData)
    }

    @Test func testRemoveKey() async throws {
        let dir = try makeTempDirectory()
        let vault = KeyVaultManager(directory: dir)
        try await vault.unlock(masterPassword: "test-password")

        let keyData = Data("some-private-key".utf8)
        try await vault.addKey(name: "doomed-key", privateKeyData: keyData)
        try await vault.removeKey(name: "doomed-key")

        do {
            _ = try await vault.getKey(name: "doomed-key")
            Issue.record("Expected VaultError.keyNotFound but no error thrown")
        } catch VaultError.keyNotFound(let name) {
            #expect(name == "doomed-key")
        }
    }

    @Test func testListKeyNames() async throws {
        let dir = try makeTempDirectory()
        let vault = KeyVaultManager(directory: dir)
        try await vault.unlock(masterPassword: "test-password")

        try await vault.addKey(name: "alpha", privateKeyData: Data("alpha-key".utf8))
        try await vault.addKey(name: "beta", privateKeyData: Data("beta-key".utf8))

        let names = try await vault.listKeyNames()
        #expect(names.contains("alpha"))
        #expect(names.contains("beta"))
        #expect(names.count == 2)
    }

    @Test func testVaultPersistsAcrossRestart() async throws {
        let dir = try makeTempDirectory()
        let keyData = Data("persistent-key-material".utf8)

        // First "session": create vault, unlock, add key
        let vault1 = KeyVaultManager(directory: dir)
        try await vault1.unlock(masterPassword: "persistent-password")
        try await vault1.addKey(name: "persistent-key", privateKeyData: keyData)

        // Second "session": new instance, same dir, same password
        let vault2 = KeyVaultManager(directory: dir)
        try await vault2.unlock(masterPassword: "persistent-password")
        let retrieved = try await vault2.getKey(name: "persistent-key")
        #expect(retrieved == keyData)
    }
}
