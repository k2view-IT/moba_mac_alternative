import Testing
import Foundation
@testable import MobaAlt

struct SSHKeyGeneratorTests {
    @Test func testGeneratesPublicAndPrivateKeyFiles() async throws {
        // Create an isolated temp directory for the vault
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vaultManager = KeyVaultManager(directory: tempDir)
        try await vaultManager.unlock(masterPassword: "test-password-123")

        let keyName = "test-key-\(UUID().uuidString)"
        let comment = "test@mobaalt"

        try await SSHKeyGenerator.generate(
            name: keyName,
            comment: comment,
            into: vaultManager
        )

        // Verify key was stored in vault
        let names = try await vaultManager.listKeyNames()
        #expect(names.contains(keyName))

        // Verify no temp files remain in /tmp with the pattern we use
        let tmpContents = try FileManager.default.contentsOfDirectory(atPath: "/tmp")
        let leftoverKeys = tmpContents.filter { $0.hasPrefix("mobaalt-keygen-") }
        #expect(leftoverKeys.isEmpty, "Temp ssh-keygen files should be cleaned up: \(leftoverKeys)")
    }
}
