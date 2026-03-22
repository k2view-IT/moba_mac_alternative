import Testing
import Foundation
@testable import MobaAlt

@MainActor
struct SFTPBrowserServiceTests {

    // MARK: - Helpers

    private func makeSUT(items: [SFTPItem] = []) -> (service: SFTPBrowserService, mock: MockSFTPChannel) {
        let mock = MockSFTPChannel()
        mock.mockItems = items
        let service = SFTPBrowserService(channel: mock, sessionId: UUID())
        return (service, mock)
    }

    // MARK: - SFTP-01: Connect / Disconnect

    @Test func testConnectSetsIsConnected() async throws {
        let (service, _) = makeSUT()
        try await service.connect()
        #expect(service.isConnected == true)
    }

    @Test func testConnectFailurePropagatesError() async throws {
        let (service, mock) = makeSUT()
        mock.shouldThrowOnConnect = true
        await #expect(throws: MockSFTPChannel.ConnectError.self) {
            try await service.connect()
        }
        #expect(service.isConnected == false)
    }

    // MARK: - SFTP-02: Directory listing

    @Test func testListDirectoryPopulatesItems() async throws {
        let sampleItem = SFTPItem(
            name: "readme.txt",
            path: "/home/user/readme.txt",
            size: 512,
            modificationDate: Date(),
            isDirectory: false,
            permissions: "-rw-r--r--"
        )
        let (service, _) = makeSUT(items: [sampleItem])
        try await service.connect()
        try await service.listDirectory(path: "~")
        #expect(service.items.count == 1)
        #expect(service.items.first?.name == "readme.txt")
    }

    // MARK: - SFTP-03: Create directory (stub — implement in 03-02)

    @Test func testCreateDirectoryCalled() async throws {
        // TODO: implement in 03-02 when createDirectory is no longer a fatalError stub
        Issue.record("testCreateDirectoryCalled: not implemented until 03-02")
    }

    // MARK: - SFTP-04: Rename (stub — implement in 03-02)

    @Test func testRenameCalled() async throws {
        // TODO: implement in 03-02 when rename is no longer a fatalError stub
        Issue.record("testRenameCalled: not implemented until 03-02")
    }

    // MARK: - SFTP-05: Delete (stub — implement in 03-02)

    @Test func testDeleteCalled() async throws {
        // TODO: implement in 03-02 when delete is no longer a fatalError stub
        Issue.record("testDeleteCalled: not implemented until 03-02")
    }
}
