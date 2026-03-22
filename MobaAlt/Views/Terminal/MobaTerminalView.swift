import AppKit
import SwiftTerm

/// A LocalProcessTerminalView subclass that adds MobaXterm-style mouse interactions:
///
/// - **Select to copy:** text selected in the terminal is automatically copied to
///   the system clipboard (no Cmd+C needed). Implemented via the `selectionChanged`
///   delegate callback in `SSHConnection`.
///
/// - **Right-click to paste:** right-clicking the terminal pastes the current
///   clipboard contents directly into the PTY stdin — no context menu, no Cmd+V.
final class MobaTerminalView: LocalProcessTerminalView {

    /// Right-click pastes clipboard text into the terminal process.
    override func rightMouseDown(with event: NSEvent) {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.isEmpty else { return }
        send(txt: text)
    }
}
