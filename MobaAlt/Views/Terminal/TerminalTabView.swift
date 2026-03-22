import SwiftUI
import AppKit
import SwiftTerm

// MARK: - TerminalTabView

/// NSViewRepresentable wrapping SSHConnection's LocalProcessTerminalView.
///
/// Starts the SSH connection exactly once when the view is first created.
/// Grants first-responder status so Cmd+C / Cmd+V and all keyboard input
/// are routed directly to the terminal, not SwiftUI.
struct TerminalTabView: NSViewRepresentable {
    let connection: SSHConnection

    func makeNSView(context: Context) -> NSView {
        // Start the connection if not already started
        if connection.terminalView == nil {
            connection.start()
        }
        let view = connection.terminalView ?? NSView()

        // Make the terminal the key window's first responder so keyboard events
        // (including Cmd+C copy, Cmd+V paste) go to the terminal, not SwiftUI.
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-focus whenever SwiftUI re-renders this view (e.g., tab switch).
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.firstResponder !== nsView {
                window.makeFirstResponder(nsView)
            }
        }
    }
}
