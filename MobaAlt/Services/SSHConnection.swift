import Foundation
import SwiftTerm
import AppKit

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
    private(set) var terminalView: LocalProcessTerminalView?

    // MARK: - Initializer

    init(tabId: UUID, session: SessionDefinition) {
        self.tabId = tabId
        self.session = session
    }

    // MARK: - Lifecycle

    /// Creates the LocalProcessTerminalView and starts the SSH process.
    /// Must be called from the main thread.
    func start() {
        guard case .ssh(let sshConfig) = session.protocolConfig else { return }

        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = self
        self.terminalView = view

        let args = SSHArgumentBuilder.build(from: sshConfig, sessionId: session.id)
        let environment = SSHArgumentBuilder.environment()

        view.startProcess(
            executable: "/usr/bin/ssh",
            args: args,
            environment: environment,
            execName: "ssh"
        )

        state = .connected
    }

    /// Terminates the SSH process and cleans up.
    /// Must be called from the main thread.
    func terminate() {
        terminalView?.processDelegate = nil
        terminalView?.terminate()
        terminalView = nil
        state = .disconnected
    }

    // MARK: - LocalProcessTerminalViewDelegate

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.state = .disconnected
            self.terminalView?.processDelegate = nil
            self.terminalView = nil
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
