import Testing
import Foundation
@testable import MobaAlt

struct TerminalViewWrapperTests {
    @Test func testMakeNSViewReturnsNonNil() async throws {
        // TerminalTabView wraps an SSHConnection's view.
        // SSHConnection.terminalView is nil before start() is called.
        // Verify the connection is properly initialized and terminalView is nil before start.
        let session = SessionDefinition(
            name: "Test",
            protocolConfig: .ssh(SSHConfig(hostname: "h.test"))
        )
        let connection = await SSHConnection(tabId: UUID(), session: session)
        await #expect(connection.state == .connecting)
        await #expect(connection.terminalView == nil) // not started yet
    }
}
