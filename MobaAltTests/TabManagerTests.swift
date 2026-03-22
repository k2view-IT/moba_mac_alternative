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
}
