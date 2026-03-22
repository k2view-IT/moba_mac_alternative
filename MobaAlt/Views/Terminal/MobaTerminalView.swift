import AppKit
import SwiftTerm

/// A LocalProcessTerminalView subclass that adds MobaXterm-style mouse interactions:
///
/// - **Select to copy:** drag-selecting text automatically copies it to the system
///   clipboard when the mouse button is released (no Cmd+C needed).
///   Uses a local NSEvent monitor because SwiftTerm's mouseUp override is non-open.
///
/// - **Right-click to paste:** right-clicking pastes the current clipboard text
///   directly into the PTY stdin — no context menu, no Cmd+V.
final class MobaTerminalView: LocalProcessTerminalView {

    private var mouseUpMonitor: Any?

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMouseUpMonitor()
        } else {
            removeMouseUpMonitor()
        }
    }

    deinit {
        removeMouseUpMonitor()
    }

    // MARK: - Right-click to paste

    override func rightMouseDown(with event: NSEvent) {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.isEmpty else { return }
        send(txt: text)
    }

    // MARK: - Private helpers

    /// Installs a process-local event monitor that fires after every left-mouse-up
    /// inside this view, triggering SwiftTerm's built-in copy if text is selected.
    private func installMouseUpMonitor() {
        guard mouseUpMonitor == nil else { return }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window else { return event }
            let locationInView = self.convert(event.locationInWindow, from: nil)
            if self.bounds.contains(locationInView) {
                // SwiftTerm's copy() is a no-op when there is no selection.
                self.copy(self)
            }
            return event
        }
    }

    private func removeMouseUpMonitor() {
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            mouseUpMonitor = nil
        }
    }
}
