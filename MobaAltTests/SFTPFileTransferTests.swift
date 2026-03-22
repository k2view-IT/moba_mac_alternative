import Testing
import Foundation
@testable import MobaAlt

@MainActor
struct SFTPFileTransferTests {

    private func makeSUT() -> (service: SFTPBrowserService, mock: MockSFTPChannel) {
        let mock = MockSFTPChannel()
        let service = SFTPBrowserService(channel: mock, sessionId: UUID())
        return (service, mock)
    }

    // MARK: - Upload

    @Test func testUploadAddsTransferTask() async throws {
        let (service, _) = makeSUT()
        try await service.connect()

        // Create a temp file to upload.
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload_test_\(UUID().uuidString).txt")
        try "hello".data(using: .utf8)!.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let stream = try await service.upload(localURL: tmpURL, toRemotePath: "/remote/")

        // Consume the stream to drive the task.
        for try await _ in stream {}

        #expect(service.transfers.count == 1)
        #expect(service.transfers.first?.direction == .upload)
        #expect(service.transfers.first?.status.isCompleted == true)
    }

    @Test func testDownloadAddsTransferTask() async throws {
        let (service, _) = makeSUT()
        try await service.connect()

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("download_test_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let stream = try await service.download(
            remotePath: "/remote/file.txt",
            toLocalURL: tmpURL
        )

        for try await _ in stream {}

        #expect(service.transfers.count == 1)
        #expect(service.transfers.first?.direction == .download)
        #expect(service.transfers.first?.status.isCompleted == true)
    }

    @Test func testUploadProgressTracking() async throws {
        let (service, _) = makeSUT()
        try await service.connect()

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_test_\(UUID().uuidString).txt")
        try "some content for progress test".data(using: .utf8)!.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        var progressEvents: [TransferProgress] = []
        let stream = try await service.upload(localURL: tmpURL, toRemotePath: "/remote/dest/")
        for try await event in stream {
            progressEvents.append(event)
        }

        #expect(!progressEvents.isEmpty)
        #expect(progressEvents.last?.fractionCompleted == 1.0)
    }

    @Test func testDownloadProgressTracking() async throws {
        let (service, _) = makeSUT()
        try await service.connect()

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl_progress_test_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        var progressEvents: [TransferProgress] = []
        let stream = try await service.download(
            remotePath: "/remote/somefile.txt",
            toLocalURL: tmpURL
        )
        for try await event in stream {
            progressEvents.append(event)
        }

        #expect(!progressEvents.isEmpty)
        #expect(progressEvents.last?.fractionCompleted == 1.0)
    }

    @Test func testMultipleSimultaneousTransfers() async throws {
        let (service, _) = makeSUT()
        try await service.connect()

        let tmp1 = FileManager.default.temporaryDirectory
            .appendingPathComponent("multi_1_\(UUID().uuidString).txt")
        let tmp2 = FileManager.default.temporaryDirectory
            .appendingPathComponent("multi_2_\(UUID().uuidString).txt")
        try "file1".data(using: .utf8)!.write(to: tmp1)
        try "file2".data(using: .utf8)!.write(to: tmp2)
        defer {
            try? FileManager.default.removeItem(at: tmp1)
            try? FileManager.default.removeItem(at: tmp2)
        }

        async let stream1 = service.upload(localURL: tmp1, toRemotePath: "/remote/")
        async let stream2 = service.upload(localURL: tmp2, toRemotePath: "/remote/")

        for try await _ in try await stream1 {}
        for try await _ in try await stream2 {}

        #expect(service.transfers.count == 2)
    }
}
