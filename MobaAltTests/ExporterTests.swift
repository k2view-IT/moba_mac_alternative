import Testing
import Foundation
@testable import MobaAlt

/// Tests for session export functionality (MobaXterm .mxtsessions, JSON, HTML).
struct ExporterTests {

    // MARK: - Helpers

    private func makeSessions() -> ([SessionDefinition], [SessionFolder]) {
        let folder = SessionFolder(id: UUID(), name: "TestFolder", parentId: nil, sortOrder: 0)
        let ssh = SessionDefinition(
            id: UUID(),
            name: "My SSH",
            folderId: nil,
            protocolConfig: .ssh(SSHConfig(hostname: "ssh.example.com", port: 22, username: "alice")),
            notes: "SSH session",
            sortOrder: 0
        )
        let rdp = SessionDefinition(
            id: UUID(),
            name: "My RDP",
            folderId: folder.id,
            protocolConfig: .rdp(RDPConfig(hostname: "rdp.example.com", port: 3389, username: "bob")),
            notes: "RDP session",
            sortOrder: 1
        )
        return ([ssh, rdp], [folder])
    }

    // MARK: - Tests

    @Test func testMXTSessionsExport() throws {
        let (sessions, folders) = makeSessions()

        // Export to .mxtsessions format
        let writer = MXTSessionsWriter()
        let exportData = try writer.export(sessions: sessions, folders: folders)

        // Re-import via parser to verify round-trip
        let parser = MXTSessionsParser()
        let result = try parser.parse(data: exportData)

        // Check sessions preserved
        let parsedSSH = result.sessions.first { $0.session.name == "My SSH" }
        #expect(parsedSSH != nil, "Round-trip: 'My SSH' should be present")
        #expect(parsedSSH?.session.protocolConfig.hostname == "ssh.example.com")
        #expect(parsedSSH?.session.protocolConfig.port == 22)
        if case .ssh(let cfg) = parsedSSH?.session.protocolConfig {
            #expect(cfg.username == "alice")
        } else {
            Issue.record("Expected SSH config after round-trip")
        }

        let parsedRDP = result.sessions.first { $0.session.name == "My RDP" }
        #expect(parsedRDP != nil, "Round-trip: 'My RDP' should be present")
        #expect(parsedRDP?.session.protocolConfig.hostname == "rdp.example.com")
        #expect(parsedRDP?.session.protocolConfig.port == 3389)

        // Folder should be preserved
        let parsedFolder = result.folders.first { $0.name == "TestFolder" }
        #expect(parsedFolder != nil, "Round-trip: 'TestFolder' folder should be present")
        // RDP session should be in the parsed folder
        #expect(parsedRDP?.folderId == parsedFolder?.id, "My RDP should be in TestFolder after round-trip")
    }

    @Test func testJSONExport() throws {
        let (sessions, folders) = makeSessions()

        let exporter = JSONExporter()
        let data = try exporter.export(sessions: sessions, folders: folders)

        // Verify valid JSON
        #expect(!data.isEmpty, "JSON export should produce non-empty data")
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            Issue.record("Expected top-level JSON dictionary")
            return
        }

        // Verify structure
        #expect(dict["sessions"] != nil, "JSON should have 'sessions' key")
        #expect(dict["version"] != nil, "JSON should have 'version' key")

        // Most important: no "password" key anywhere in the JSON
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        #expect(!jsonString.contains("\"password\""), "JSON export must not contain any 'password' keys")
        #expect(!jsonString.contains("privateKey"), "JSON export must not contain 'privateKey' values")

        // Verify it's valid UTF-8
        #expect(String(data: data, encoding: .utf8) != nil, "JSON export must be valid UTF-8")
    }

    @Test func testHTMLExport() throws {
        let (sessions, folders) = makeSessions()

        let exporter = HTMLExporter()
        let html = exporter.export(sessions: sessions, folders: folders)

        // Basic structure checks
        #expect(html.contains("<table"), "HTML export must contain a <table> element")
        #expect(html.contains("My SSH"), "HTML export must contain session name 'My SSH'")
        #expect(html.contains("ssh.example.com"), "HTML export must contain hostname 'ssh.example.com'")
        #expect(html.contains("<meta charset=\"utf-8\">"), "HTML export must have UTF-8 charset meta tag")

        // Verify it's valid UTF-8
        #expect(html.data(using: .utf8) != nil, "HTML export must be encodable as UTF-8")

        // Should not contain passwords
        #expect(!html.contains("password"), "HTML export must not contain password fields")
    }
}
