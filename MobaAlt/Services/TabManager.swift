import Foundation

// MARK: - TabItem

/// Represents an open tab in the tab bar.
struct TabItem: Identifiable {
    let id: UUID
    let sessionId: UUID
    var displayName: String
    let connection: SSHConnection
}

// MARK: - TabManager

/// @Observable class that manages the lifecycle of SSH session tabs.
///
/// All mutations should occur on the main thread because the @Observable
/// macro integrates with SwiftUI observation on the main actor.
@Observable
@MainActor
final class TabManager {

    // MARK: - Properties

    var tabs: [TabItem] = []
    var activeTabId: UUID?

    // MARK: - Tab Operations

    /// Opens a new tab for the given session definition.
    ///
    /// - Parameter session: The session to open.
    /// - Returns: The newly created TabItem.
    @discardableResult
    func openTab(for session: SessionDefinition) -> TabItem {
        let tabId = UUID()
        let connection = SSHConnection(tabId: tabId, session: session)
        let item = TabItem(
            id: tabId,
            sessionId: session.id,
            displayName: session.name,
            connection: connection
        )
        tabs.append(item)
        activeTabId = tabId
        return item
    }

    /// Closes the tab with the given id, terminating its SSH connection.
    ///
    /// - Parameter tabId: The id of the tab to close.
    func closeTab(_ tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        let tab = tabs[index]
        tab.connection.terminate()
        tabs.remove(at: index)

        // Update active tab if we closed the active one
        if activeTabId == tabId {
            activeTabId = tabs.last?.id
        }
    }

    /// Sets the active tab to the given tab id.
    ///
    /// - Parameter tabId: The id of the tab to activate.
    func activateTab(_ tabId: UUID) {
        guard tabs.contains(where: { $0.id == tabId }) else { return }
        activeTabId = tabId
    }

    /// Returns all connections that are in the .connected state.
    /// Used to enumerate active SSH sessions for port-forward display (SSH-06).
    var activeConnections: [SSHConnection] {
        tabs.compactMap { tab in
            tab.connection.state == .connected ? tab.connection : nil
        }
    }
}
