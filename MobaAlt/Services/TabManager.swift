import Foundation

// MARK: - TabItem

/// Represents an open tab in the tab bar.
struct TabItem: Identifiable {
    let id: UUID
    let sessionId: UUID
    var displayName: String
    let connection: SSHConnection

    // MARK: - SFTP state

    /// Per-tab override for where the SFTP panel appears. Starts at the app-level default.
    var sftpPosition: SFTPPanelPosition

    /// The SFTP service instance owned by this tab. Created in openTab(for:) alongside
    /// the SSHConnection and torn down in closeTab(_:).
    let sftpService: SFTPBrowserService
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

    /// Factory closure for creating SFTP channels. Override in tests with MockSFTPChannel.
    var sftpChannelFactory: (_ sessionId: UUID, _ config: SSHConfig) -> SFTPChannel = { sessionId, config in
        let socketPath = SSHArgumentBuilder.controlPath(for: sessionId)
        return SFTPSubprocessChannel(socketPath: socketPath, config: config)
    }

    // MARK: - Tab Operations

    /// Opens a new tab for the given session definition.
    ///
    /// - Parameter session: The session to open.
    /// - Returns: The newly created TabItem.
    @discardableResult
    func openTab(for session: SessionDefinition) -> TabItem {
        let tabId = UUID()
        let connection = SSHConnection(tabId: tabId, session: session)

        // Determine default SFTP panel position from UserDefaults.
        let rawDefault = UserDefaults.standard.string(forKey: "sftpDefaultPosition") ?? "left"
        let defaultPos = SFTPPanelPosition(rawValue: rawDefault) ?? .left

        // Create SFTP channel and service (injectable via sftpChannelFactory for tests).
        guard case .ssh(let sshConfig) = session.protocolConfig else {
            // Non-SSH sessions: create a mock channel that silently no-ops.
            let channel = MockSFTPChannel()
            let sftpService = SFTPBrowserService(channel: channel, sessionId: tabId)
            let item = TabItem(
                id: tabId,
                sessionId: session.id,
                displayName: session.name,
                connection: connection,
                sftpPosition: defaultPos,
                sftpService: sftpService
            )
            tabs.append(item)
            activeTabId = tabId
            return item
        }

        let channel = sftpChannelFactory(tabId, sshConfig)
        let sftpService = SFTPBrowserService(channel: channel, sessionId: tabId)

        let item = TabItem(
            id: tabId,
            sessionId: session.id,
            displayName: session.name,
            connection: connection,
            sftpPosition: defaultPos,
            sftpService: sftpService
        )
        tabs.append(item)
        activeTabId = tabId

        // Observe the SSHConnection state and auto-connect SFTP when SSH becomes connected.
        // Uses withObservationTracking to react to @Observable state changes.
        Task { @MainActor [weak self] in
            guard let self else { return }
            while let currentTab = self.tabs.first(where: { $0.id == tabId }) {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = currentTab.connection.state
                    } onChange: {
                        continuation.resume()
                    }
                }
                // Re-fetch the tab after state change.
                guard let updatedTab = self.tabs.first(where: { $0.id == tabId }) else { break }
                if updatedTab.connection.state == .connected && !updatedTab.sftpService.isConnected {
                    try? await updatedTab.sftpService.connect()
                }
            }
        }

        return item
    }

    /// Closes the tab with the given id, terminating its SSH connection and SFTP service.
    ///
    /// - Parameter tabId: The id of the tab to close.
    func closeTab(_ tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        let tab = tabs[index]
        tab.connection.terminate()
        // Disconnect SFTP service before removing tab to clean up the subprocess.
        Task { await tab.sftpService.disconnect() }
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

    /// Updates the SFTP panel position for the given tab. Called by the toolbar button.
    ///
    /// - Parameters:
    ///   - position: The new panel position.
    ///   - tabId: The tab to update.
    func setSFTPPosition(_ position: SFTPPanelPosition, for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[index].sftpPosition = position
    }

    /// Returns all connections that are in the .connected state.
    /// Used to enumerate active SSH sessions for port-forward display (SSH-06).
    var activeConnections: [SSHConnection] {
        tabs.compactMap { tab in
            tab.connection.state == .connected ? tab.connection : nil
        }
    }
}
