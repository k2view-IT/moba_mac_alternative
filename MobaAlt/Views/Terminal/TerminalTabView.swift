import SwiftUI
import AppKit
import SwiftTerm

// MARK: - TerminalTabView

/// NSViewRepresentable wrapping SSHConnection's LocalProcessTerminalView.
///
/// Starts the SSH connection exactly once when the view is first created.
/// The terminal manages its own rendering — updateNSView is intentionally a no-op.
struct TerminalTabView: NSViewRepresentable {
    let connection: SSHConnection

    func makeNSView(context: Context) -> NSView {
        // Start the connection if not already started
        if connection.terminalView == nil {
            connection.start()
        }
        // Return the terminal view if available, otherwise a placeholder
        return connection.terminalView ?? NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Terminal manages its own rendering — no-op
    }
}
