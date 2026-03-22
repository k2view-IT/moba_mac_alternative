import Testing
import Foundation
@testable import MobaAlt

@MainActor
struct TabManagerTests {

    private func makeSession(name: String = "Test Session") -> SessionDefinition {
        SessionDefinition(
            id: UUID(),
            name: name,
            protocolConfig: .ssh(SSHConfig(hostname: "example.com"))
        )
    }

    @Test func testOpenTabIncrementsCount() async throws {
        let manager = TabManager()
        let session = makeSession()
        _ = manager.openTab(for: session)
        #expect(manager.tabs.count == 1)
    }

    @Test func testCloseTabDecrementsCount() async throws {
        let manager = TabManager()
        let session = makeSession()
        let tab = manager.openTab(for: session)
        manager.closeTab(tab.id)
        #expect(manager.tabs.count == 0)
    }

    @Test func testActivateTab() async throws {
        let manager = TabManager()
        let s1 = makeSession(name: "S1")
        let s2 = makeSession(name: "S2")
        _ = manager.openTab(for: s1)
        let tab2 = manager.openTab(for: s2)
        manager.activateTab(tab2.id)
        #expect(manager.activeTabId == tab2.id)
    }

    @Test func testActiveConnectionsExposesPortForwards() async throws {
        let manager = TabManager()
        // No tabs opened, so no connected connections
        #expect(manager.activeConnections.isEmpty)
    }

    // MARK: - SFTP lifecycle tests

    @Test func testOpenTabCreatesSFTPService() async throws {
        let manager = TabManager()
        let mockChannel = MockSFTPChannel()
        manager.sftpChannelFactory = { _, _ in mockChannel }
        let session = makeSession()
        let tab = manager.openTab(for: session)
        // sftpService is created and stored on the tab
        #expect(tab.sftpService != nil)
    }

    @Test func testCloseTabDisconnectsSFTPService() async throws {
        let manager = TabManager()
        let mockChannel = MockSFTPChannel()
        manager.sftpChannelFactory = { _, _ in mockChannel }
        let session = makeSession()
        let tab = manager.openTab(for: session)
        // Simulate connected state
        mockChannel.didConnect = true
        manager.closeTab(tab.id)
        // Disconnect is async — wait for the Task to run
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        #expect(mockChannel.didConnect == false)
    }

    @Test func testSetSFTPPositionUpdatesTab() async throws {
        let manager = TabManager()
        let mockChannel = MockSFTPChannel()
        manager.sftpChannelFactory = { _, _ in mockChannel }
        let session = makeSession()
        let tab = manager.openTab(for: session)
        manager.setSFTPPosition(.right, for: tab.id)
        let updated = manager.tabs.first(where: { $0.id == tab.id })
        #expect(updated?.sftpPosition == .right)
    }

    @Test func testSFTPServiceConnectsWhenSSHConnects() async throws {
        let manager = TabManager()
        let mockChannel = MockSFTPChannel()
        manager.sftpChannelFactory = { _, _ in mockChannel }
        let session = makeSession()
        let tab = manager.openTab(for: session)
        // Yield to let the observation Task start and register its withObservationTracking call.
        await Task.yield()
        // SSHConnection.start() sets state = .connected synchronously at the end of the method.
        // The NSView creation and process launch may fail silently; state is still set.
        tab.connection.start()
        // Allow the observation task and async connect to run (up to 500ms).
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms per iteration
            if mockChannel.didConnect { break }
        }
        #expect(mockChannel.didConnect == true)
    }
}
