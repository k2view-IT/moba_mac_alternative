import Testing
import Foundation
@testable import MobaAlt

struct SSHArgumentBuilderTests {

    // MARK: - Helpers

    private func makeConfig(
        hostname: String = "example.com",
        port: Int = 22,
        username: String = "alice",
        authMethod: SSHAuthMethod = .password,
        privateKeyPath: String = "",
        x11Forwarding: Bool = false,
        agentForwarding: Bool = false,
        portForwardingRules: [PortForwardingRule] = []
    ) -> SSHConfig {
        SSHConfig(
            hostname: hostname,
            port: port,
            username: username,
            authMethod: authMethod,
            privateKeyPath: privateKeyPath,
            x11Forwarding: x11Forwarding,
            agentForwarding: agentForwarding,
            portForwardingRules: portForwardingRules
        )
    }

    // MARK: - Tests

    @Test func testBasicArgs() async throws {
        let config = makeConfig(hostname: "example.com", port: 22, username: "alice")
        let sessionId = UUID()
        let args = SSHArgumentBuilder.build(from: config, sessionId: sessionId)
        #expect(args.contains("-l"))
        #expect(args.contains("alice"))
        #expect(args.last == "example.com")
        #expect(!args.contains("-p"))
    }

    @Test func testNonDefaultPort() async throws {
        let config = makeConfig(port: 2222)
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-p"))
        #expect(args.contains("2222"))
    }

    @Test func testOmitsDefaultPort() async throws {
        let config = makeConfig(port: 22)
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(!args.contains("-p"))
    }

    @Test func testOmitsEmptyUsername() async throws {
        let config = makeConfig(username: "")
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(!args.contains("-l"))
    }

    @Test func testAgentForwardingFlag() async throws {
        let config = makeConfig(agentForwarding: true)
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-A"))
    }

    @Test func testAgentForwarding() async throws {
        let config = makeConfig(authMethod: .agent)
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-A"))
    }

    @Test func testPrivateKeyFlag() async throws {
        let config = makeConfig(authMethod: .privateKey, privateKeyPath: "/tmp/key")
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-i"))
        #expect(args.contains("/tmp/key"))
    }

    @Test func testPortForwardingLocal() async throws {
        let rule = PortForwardingRule(direction: .local, localPort: 8080, remotePort: 80)
        let config = makeConfig(portForwardingRules: [rule])
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-L"))
        #expect(args.contains("8080:localhost:80"))
    }

    @Test func testPortForwardingRemote() async throws {
        let rule = PortForwardingRule(direction: .remote, localPort: 3000, remotePort: 3000)
        let config = makeConfig(portForwardingRules: [rule])
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-R"))
        #expect(args.contains("3000:localhost:3000"))
    }

    @Test func testPortForwardingDynamic() async throws {
        let rule = PortForwardingRule(direction: .dynamic, localPort: 1080, remotePort: 0)
        let config = makeConfig(portForwardingRules: [rule])
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        #expect(args.contains("-D"))
        #expect(args.contains("1080"))
    }

    @Test func testControlMasterArgs() async throws {
        let config = makeConfig()
        let args = SSHArgumentBuilder.build(from: config, sessionId: UUID())
        // -o ControlMaster=auto must be present
        let omIdx = args.firstIndex(of: "-o")
        #expect(omIdx != nil)
        #expect(args.contains("ControlMaster=auto"))
        #expect(args.contains("ControlPersist=no"))
    }

    @Test func testControlPathLength() async throws {
        let path = SSHArgumentBuilder.controlPath(for: UUID())
        #expect(path.count < 104)
    }

    @Test func testEnvironmentContainsTERM() async throws {
        let env = SSHArgumentBuilder.environment()
        #expect(env.contains("TERM=xterm-256color"))
    }

    @Test func testEnvironmentContainsLANG() async throws {
        let env = SSHArgumentBuilder.environment()
        #expect(env.contains("LANG=en_US.UTF-8"))
    }
}
