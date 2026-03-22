import Foundation

/// A generated ed25519 key pair.
struct GeneratedKeyPair {
    let publicKeyData: Data     // Contents of the .pub file
    let privateKeyData: Data    // Contents of the private key file
    let comment: String
}

/// Generates ed25519 SSH key pairs by shelling out to /usr/bin/ssh-keygen.
///
/// Does NOT use SecKeyCreateRandomKey — the OpenSSH format produced by ssh-keygen
/// is incompatible with SecKey and is required for direct use with ssh clients.
struct SSHKeyGenerator {

    /// Generates an ed25519 key pair and stores the private key in the vault.
    ///
    /// - Parameters:
    ///   - name: The name used to identify the key in the vault.
    ///   - comment: The comment embedded in the public key (typically "user@host").
    ///   - vaultManager: The unlocked KeyVaultManager that will store the private key.
    /// - Throws: An error if ssh-keygen fails or if the vault operation fails.
    static func generate(
        name: String,
        comment: String,
        into vaultManager: KeyVaultManager
    ) async throws {
        // Use a unique temp directory for the key pair to avoid name collisions
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mobaalt-keygen-\(UUID().uuidString)", isDirectory: true)
        let keyPath = tempDir.appendingPathComponent("id_ed25519")
        let pubKeyPath = tempDir.appendingPathComponent("id_ed25519.pub")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Always clean up temp files, even on error
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Run ssh-keygen synchronously in a detached task to avoid blocking the actor
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
            process.arguments = [
                "-t", "ed25519",
                "-C", comment,
                "-f", keyPath.path,
                "-N", ""    // Empty passphrase — vault handles encryption
            ]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
                throw SSHKeyGeneratorError.keygen("ssh-keygen failed (exit \(process.terminationStatus)): \(errMsg)")
            }
        }.value

        // Read generated key files
        let privateKeyData = try Data(contentsOf: keyPath)
        let publicKeyData = try Data(contentsOf: pubKeyPath)

        // Store private key in vault
        try await vaultManager.addKey(name: name, privateKeyData: privateKeyData)

        _ = GeneratedKeyPair(
            publicKeyData: publicKeyData,
            privateKeyData: privateKeyData,
            comment: comment
        )
        // Temp files cleaned up by defer above
    }
}

// MARK: - Errors

enum SSHKeyGeneratorError: Error, LocalizedError {
    case keygen(String)

    var errorDescription: String? {
        switch self {
        case .keygen(let msg): return "SSH key generation failed: \(msg)"
        }
    }
}
