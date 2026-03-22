import Testing
import Foundation
@testable import MobaAlt

struct SSHConnectionTests {
    @Test func testEnvironmentContainsTERM() async throws {
        let env = SSHArgumentBuilder.environment()
        #expect(env.contains("TERM=xterm-256color"))
    }
}
