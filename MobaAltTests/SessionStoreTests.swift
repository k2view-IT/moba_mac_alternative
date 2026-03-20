import Testing
import Foundation
@testable import MobaAlt

struct SessionStoreTests {

    // MARK: - Helpers

    /// Creates a temporary directory for each test run (avoids using real Application Support).
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Tests

    @Test func testCreateSession() async throws {
        let tempDir = try makeTempDirectory()
        let store = SessionStore(directory: tempDir)

        let createdAt = Date(timeIntervalSinceReferenceDate: 800_000_000)  // fixed timestamp
        let session = SessionDefinition(
            id: UUID(),
            name: "Test SSH",
            folderId: nil,
            protocolConfig: .ssh(SSHConfig(
                hostname: "192.168.1.1",
                port: 2222,
                username: "admin",
                authMethod: .privateKey,
                privateKeyPath: "/home/user/.ssh/id_rsa",
                x11Forwarding: true,
                agentForwarding: false
            )),
            notes: "My test server",
            sortOrder: 5,
            createdAt: createdAt,
            lastConnected: nil
        )

        // Save
        try await store.save(sessions: [session], folders: [])

        // Reload
        let (loadedSessions, loadedFolders) = try await store.load()

        #expect(loadedFolders.isEmpty)
        #expect(loadedSessions.count == 1)

        let loaded = try #require(loadedSessions.first)
        #expect(loaded.id == session.id)
        #expect(loaded.name == session.name)
        #expect(loaded.folderId == nil)
        #expect(loaded.notes == "My test server")
        #expect(loaded.sortOrder == 5)

        // Timestamp precision to seconds (ISO8601 format)
        #expect(Int(loaded.createdAt.timeIntervalSinceReferenceDate) == Int(createdAt.timeIntervalSinceReferenceDate))
        #expect(loaded.lastConnected == nil)

        // Protocol config round-trip
        if case .ssh(let cfg) = loaded.protocolConfig {
            #expect(cfg.hostname == "192.168.1.1")
            #expect(cfg.port == 2222)
            #expect(cfg.username == "admin")
            #expect(cfg.authMethod == .privateKey)
            #expect(cfg.privateKeyPath == "/home/user/.ssh/id_rsa")
            #expect(cfg.x11Forwarding == true)
            #expect(cfg.agentForwarding == false)
        } else {
            Issue.record("Expected SSH config but got \(loaded.protocolConfig)")
        }
    }

    @Test func testFolderHierarchy() async throws {
        let tempDir = try makeTempDirectory()
        let store = SessionStore(directory: tempDir)

        let parentFolder = SessionFolder(
            id: UUID(),
            name: "Production",
            parentId: nil,
            sortOrder: 0
        )
        let childFolder = SessionFolder(
            id: UUID(),
            name: "Database",
            parentId: parentFolder.id,
            sortOrder: 1
        )

        let sessionInParent = SessionDefinition(
            name: "Web Server",
            folderId: parentFolder.id,
            protocolConfig: .ssh(SSHConfig(hostname: "10.0.0.1")),
            sortOrder: 0
        )
        let sessionInChild = SessionDefinition(
            name: "DB Monitor",
            folderId: childFolder.id,
            protocolConfig: .vnc(VNCConfig(hostname: "10.0.0.10")),
            sortOrder: 2
        )

        // Save with both sessions and folders
        try await store.save(
            sessions: [sessionInChild, sessionInParent],  // intentionally out of order
            folders: [childFolder, parentFolder]
        )

        // Reload and verify
        let (loadedSessions, loadedFolders) = try await store.load()

        #expect(loadedFolders.count == 2)
        #expect(loadedSessions.count == 2)

        // Verify folder parentId relationship is preserved
        let loadedParent = try #require(loadedFolders.first { $0.id == parentFolder.id })
        let loadedChild = try #require(loadedFolders.first { $0.id == childFolder.id })
        #expect(loadedParent.parentId == nil)
        #expect(loadedChild.parentId == parentFolder.id)

        // Verify sessions load (sortOrder preserved)
        let loadedInParent = try #require(loadedSessions.first { $0.folderId == parentFolder.id })
        let loadedInChild = try #require(loadedSessions.first { $0.folderId == childFolder.id })
        #expect(loadedInParent.sortOrder == 0)
        #expect(loadedInChild.sortOrder == 2)
        #expect(loadedInParent.name == "Web Server")
        #expect(loadedInChild.name == "DB Monitor")
    }
}
