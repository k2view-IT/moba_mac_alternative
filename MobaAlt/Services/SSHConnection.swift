import Foundation
import SwiftTerm
import AppKit
import Security

// MARK: - SSHConnectionState

enum SSHConnectionState {
    case connecting
    case connected
    case disconnected
}

// MARK: - SSHConnection

/// Manages the lifecycle of a single SSH session backed by SwiftTerm's
/// LocalProcessTerminalView with a pseudo-terminal.
///
/// Must be created, started, and terminated on the main thread.
@Observable
@MainActor
final class SSHConnection: LocalProcessTerminalViewDelegate {

    // MARK: - Properties

    let tabId: UUID
    let session: SessionDefinition

    private(set) var state: SSHConnectionState = .connecting
    var logWriter: SessionLogWriter?

    /// The underlying SwiftTerm NSView. Nil until start() is called.
    private(set) var terminalView: MobaTerminalView?

    /// Path of the temporary SSH_ASKPASS script, cleaned up on terminate().
    private var askPassScriptPath: String?

    // MARK: - Initializer

    init(tabId: UUID, session: SessionDefinition) {
        self.tabId = tabId
        self.session = session
    }

    // MARK: - Lifecycle

    /// Creates the LocalProcessTerminalView and starts the SSH process.
    /// Automatically injects a Keychain-stored password via SSH_ASKPASS if
    /// the session uses password auth — the user will never see a password prompt.
    /// Must be called from the main thread.
    func start() {
        guard case .ssh(let sshConfig) = session.protocolConfig else { return }

        let view = MobaTerminalView(frame: .zero)
        view.processDelegate = self
        self.terminalView = view

        let args = SSHArgumentBuilder.build(from: sshConfig, sessionId: session.id)
        var environment = SSHArgumentBuilder.environment()

        // Password injection: if the session uses password auth and a password
        // is stored in Keychain, write a minimal SSH_ASKPASS helper script so
        // /usr/bin/ssh never shows an interactive prompt.
        if sshConfig.authMethod == .password,
           let password = keychainPassword(for: session.id),
           let scriptPath = writeAskPassScript(password: password) {
            askPassScriptPath = scriptPath
            environment.append("SSH_ASKPASS=\(scriptPath)")
            // SSH_ASKPASS_REQUIRE=force works on OpenSSH 8.4+; DISPLAY=:0 is a
            // fallback for older versions that require a DISPLAY to use SSH_ASKPASS.
            environment.append("SSH_ASKPASS_REQUIRE=force")
            environment.append("DISPLAY=:0")
        }

        view.startProcess(
            executable: "/usr/bin/ssh",
            args: args,
            environment: environment,
            execName: "ssh"
        )

        state = .connected
    }

    /// Terminates the SSH process and cleans up resources including the
    /// temporary SSH_ASKPASS script if one was created.
    /// Must be called from the main thread.
    func terminate() {
        terminalView?.processDelegate = nil
        terminalView?.terminate()
        terminalView = nil
        state = .disconnected
        cleanUpAskPassScript()
    }

    // MARK: - Private helpers

    /// Reads the stored password for the given session UUID directly from the
    /// macOS Keychain via synchronous SecItemCopyMatching (safe on @MainActor).
    private func keychainPassword(for sessionId: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.mobaalt.MobaAlt",
            kSecAttrAccount: sessionId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let pw = String(data: data, encoding: .utf8),
              !pw.isEmpty else { return nil }
        return pw
    }

    /// Writes a tiny executable shell script that prints the password to stdout.
    /// SSH calls this script instead of prompting the user.
    /// Returns the script path, or nil if writing failed.
    private func writeAskPassScript(password: String) -> String? {
        // Single-quote the password and escape any single-quotes inside it.
        let escaped = password.replacingOccurrences(of: "'", with: "'\\''")
        let script = "#!/bin/sh\nprintf '%s' '\(escaped)'\n"
        let path = "/tmp/mobaalt-askpass-\(String(tabId.uuidString.prefix(8)).lowercased()).sh"
        do {
            try script.write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o700))],
                ofItemAtPath: path
            )
            return path
        } catch {
            return nil
        }
    }

    private func cleanUpAskPassScript() {
        if let path = askPassScriptPath {
            try? FileManager.default.removeItem(atPath: path)
            askPassScriptPath = nil
        }
    }

    // MARK: - LocalProcessTerminalViewDelegate

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.state = .disconnected
            self.terminalView?.processDelegate = nil
            self.terminalView = nil
            self.cleanUpAskPassScript()
        }
    }

    /// Auto-copy: whenever the user finishes selecting text, invoke SwiftTerm's
    /// built-in copy handler which pushes the selection to NSPasteboard.
    /// This is the MobaXterm "select = copy" behaviour — no Cmd+C needed.
    nonisolated func selectionChanged(source: TerminalView) {
        DispatchQueue.main.async {
            source.copy(source)
        }
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // Terminal resized — handled automatically by LocalProcessTerminalView
    }

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        // Title changes can be forwarded to the tab display name if needed
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Working directory changes — can be used for tab display in future
    }
}
