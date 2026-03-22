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

    private func makeSFTPItem(name: String, isDirectory: Bool = false, size: Int64 = 512) -> SFTPItem {
        SFTPItem(
            name: name,
            path: "/home/user/\(name)",
            size: size,
            modificationDate: Date(),
            isDirectory: isDirectory,
            permissions: isDirectory ? "drwxr-xr-x" : "-rw-r--r--"
        )
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
        let sampleItem = makeSFTPItem(name: "readme.txt")
        let (service, _) = makeSUT(items: [sampleItem])
        try await service.connect()
        try await service.listDirectory(path: "~")
        #expect(service.items.count == 1)
        #expect(service.items.first?.name == "readme.txt")
    }

    @Test func testListDirectoryHidesDotfiles() async throws {
        let hidden = makeSFTPItem(name: ".hidden")
        let visible = makeSFTPItem(name: "visible.txt")
        let (service, _) = makeSUT(items: [hidden, visible])
        service.showHidden = false
        try await service.connect()
        try await service.listDirectory(path: "~")
        #expect(service.items.count == 1)
        #expect(service.items.first?.name == "visible.txt")
    }

    @Test func testListDirectoryShowsDotfilesWhenEnabled() async throws {
        let hidden = makeSFTPItem(name: ".hidden")
        let visible = makeSFTPItem(name: "visible.txt")
        let (service, _) = makeSUT(items: [hidden, visible])
        service.showHidden = true
        try await service.connect()
        try await service.listDirectory(path: "~")
        #expect(service.items.count == 2)
    }

    @Test func testListDirectorySortsFoldersFirst() async throws {
        let file = makeSFTPItem(name: "aardvark.txt", isDirectory: false)
        let dir = makeSFTPItem(name: "zoo", isDirectory: true)
        let (service, _) = makeSUT(items: [file, dir])
        try await service.connect()
        try await service.listDirectory(path: "~")
        #expect(service.items.first?.isDirectory == true)
        #expect(service.items.last?.isDirectory == false)
    }

    // MARK: - SFTP-03: Create directory

    @Test func testCreateDirectoryCalled() async throws {
        let (service, mock) = makeSUT()
        try await service.connect()
        try await service.createDirectory(at: "/foo/newdir")
        #expect(mock.lastCommand?.contains("mkdir") == true)
        #expect(mock.lastCommand?.contains("/foo/newdir") == true)
    }

    // MARK: - SFTP-04: Rename

    @Test func testRenameCalled() async throws {
        let (service, mock) = makeSUT()
        try await service.connect()
        try await service.rename(from: "/old", to: "/new")
        #expect(mock.lastCommand?.contains("rename") == true)
        #expect(mock.lastCommand?.contains("/old") == true)
        #expect(mock.lastCommand?.contains("/new") == true)
    }

    // MARK: - SFTP-05: Delete

    @Test func testDeleteCalled() async throws {
        let (service, mock) = makeSUT()
        try await service.connect()
        try await service.delete(at: "/some/file.txt")
        #expect(mock.lastCommand?.contains("rm") == true)
        #expect(mock.lastCommand?.contains("/some/file.txt") == true)
    }

    // MARK: - parseLsLine

    @Test func testParseLsLineFile() {
        let channel = SFTPSubprocessChannel(
            socketPath: "/tmp/dummy.sock",
            config: SSHConfig(hostname: "host", port: 22, username: "user")
        )
        let line = "-rw-r--r--  1 user group  2048 Jan  5 14:23 readme.txt"
        let item = channel.parseLsLine(line, basePath: "/home/user")
        #expect(item != nil)
        #expect(item?.name == "readme.txt")
        #expect(item?.size == 2048)
        #expect(item?.isDirectory == false)
        #expect(item?.permissions == "-rw-r--r--")
    }

    @Test func testParseLsLineDirectory() {
        let channel = SFTPSubprocessChannel(
            socketPath: "/tmp/dummy.sock",
            config: SSHConfig(hostname: "host", port: 22, username: "user")
        )
        let line = "drwxr-xr-x  3 user group  4096 Mar 10 2023 mydir"
        let item = channel.parseLsLine(line, basePath: "/home/user")
        #expect(item != nil)
        #expect(item?.name == "mydir")
        #expect(item?.isDirectory == true)
    }

    @Test func testParseLsLineSkipsDotEntries() {
        let channel = SFTPSubprocessChannel(
            socketPath: "/tmp/dummy.sock",
            config: SSHConfig(hostname: "host", port: 22, username: "user")
        )
        let dotLine = "drwxr-xr-x  2 user group 4096 Jan  5 14:23 ."
        let dotDotLine = "drwxr-xr-x  2 user group 4096 Jan  5 14:23 .."
        #expect(channel.parseLsLine(dotLine, basePath: "/home/user") == nil)
        #expect(channel.parseLsLine(dotDotLine, basePath: "/home/user") == nil)
    }
}
