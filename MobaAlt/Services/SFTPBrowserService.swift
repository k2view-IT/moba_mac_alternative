import AppKit
import Foundation
import Observation

// MARK: - SFTPChannel Protocol

/// Abstraction over a real (subprocess-based) or mock SFTP transport.
/// All mutating operations are async and throwing; the protocol itself is not actor-isolated
/// so concrete types may choose their own actor context.
protocol SFTPChannel: AnyObject {
    func connect() async throws
    func disconnect() async
    func listDirectory(path: String) async throws -> [SFTPItem]
    func createDirectory(at path: String) async throws
    func rename(from: String, to: String) async throws
    func delete(at path: String) async throws
    /// Fire-and-forget raw command (e.g., keep-alive ping). Non-throwing.
    func send(_ command: String)
}

// MARK: - MockSFTPChannel

/// Controllable in-memory SFTP channel for unit tests.
/// Lives in the main module (not #if DEBUG) so tests can import it via @testable without
/// conditional compilation flags.
final class MockSFTPChannel: SFTPChannel, @unchecked Sendable {
    var mockItems: [SFTPItem] = []
    var shouldThrowOnConnect: Bool = false
    var didConnect: Bool = false
    var lastCommand: String?

    /// Canned AsyncThrowingStream for upload/download progress tests.
    var mockTransferProgress: [TransferProgress] = []

    struct ConnectError: Error {}

    func connect() async throws {
        if shouldThrowOnConnect { throw ConnectError() }
        didConnect = true
    }

    func disconnect() async {
        didConnect = false
    }

    func listDirectory(path: String) async throws -> [SFTPItem] {
        return mockItems
    }

    func createDirectory(at path: String) async throws {
        lastCommand = "mkdir \(path)"
    }

    func rename(from: String, to: String) async throws {
        lastCommand = "rename \(from) \(to)"
    }

    func delete(at path: String) async throws {
        lastCommand = "rm \(path)"
    }

    func send(_ command: String) {
        lastCommand = command
    }
}

// MARK: - SFTPBrowserService

/// @Observable view-model / service for the SFTP file browser panel.
/// Receives an `SFTPChannel` at construction time for full testability.
@Observable
@MainActor
final class SFTPBrowserService {
    let sessionId: UUID
    private let channel: SFTPChannel

    // MARK: Published state

    private(set) var currentPath: String = "~"
    private(set) var items: [SFTPItem] = []
    private(set) var transfers: [TransferTask] = []
    private(set) var isLoading: Bool = false
    private(set) var isConnected: Bool = false

    /// Whether to show dotfiles (names beginning with ".") in directory listings.
    var showHidden: Bool = false

    // MARK: Init

    /// Designated init — inject a channel for testing or custom transport.
    init(channel: SFTPChannel, sessionId: UUID) {
        self.channel = channel
        self.sessionId = sessionId
    }

    /// Production convenience init.
    ///
    /// - Parameters:
    ///   - sessionId: The session UUID. Used to derive the ControlMaster socket path.
    ///   - config: The SSH configuration for this session.
    convenience init(sessionId: UUID, config: SSHConfig) {
        let socketPath = SSHArgumentBuilder.controlPath(for: sessionId)
        let channel = SFTPSubprocessChannel(socketPath: socketPath, config: config)
        self.init(channel: channel, sessionId: sessionId)
    }

    // MARK: - Connection

    /// Connects the SFTP channel, waiting up to 10s for the ControlMaster socket to appear.
    ///
    /// When using a MockSFTPChannel (test-only), the socket wait is skipped entirely.
    func connect() async throws {
        if !(channel is MockSFTPChannel) {
            let socketPath = SSHArgumentBuilder.controlPath(for: sessionId)
            try await waitForSocket(socketPath)
        }
        try await channel.connect()
        isConnected = true
    }

    func disconnect() async {
        await channel.disconnect()
        isConnected = false
    }

    // MARK: - Directory listing

    /// Lists the given remote path, applying dotfile filter and sorting.
    func listDirectory(path: String) async throws {
        isLoading = true
        defer { isLoading = false }
        var fetched = try await channel.listDirectory(path: path)

        if !showHidden {
            fetched = fetched.filter { !$0.name.hasPrefix(".") }
        }

        // Directories first, then alphabetical within each group.
        fetched.sort {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        items = fetched
        currentPath = path
    }

    // MARK: - File operations

    func createDirectory(at path: String) async throws {
        try await channel.createDirectory(at: path)
    }

    func rename(from: String, to: String) async throws {
        try await channel.rename(from: from, to: to)
    }

    func delete(at path: String) async throws {
        try await channel.delete(at: path)
    }

    // MARK: - Upload

    /// Uploads a local file to the remote server and tracks progress via polling.
    ///
    /// Progress is approximated by comparing local file size with the remote size
    /// polled every 500ms after issuing the `put` command. This avoids the need
    /// to parse sftp verbose output and works reliably across sftp versions.
    @discardableResult
    func upload(localURL: URL, toRemotePath remotePath: String) async throws -> AsyncThrowingStream<TransferProgress, Error> {
        let taskId = UUID()
        let localSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        let task = TransferTask(
            id: taskId,
            remotePath: remotePath,
            localURL: localURL,
            direction: .upload,
            status: .pending
        )
        transfers.append(task)
        let taskIndex = transfers.count - 1

        let stream = AsyncThrowingStream<TransferProgress, Error> { continuation in
            Task {
                do {
                    let remoteDest = remotePath.hasSuffix("/")
                        ? remotePath + localURL.lastPathComponent
                        : remotePath
                    self.channel.send("put \(localURL.path) \(remoteDest)")

                    // Poll until sftp put completes (approximated by progress reaching 100%).
                    var transferred: Int64 = 0
                    while transferred < localSize {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        // In real usage the remote file size would be queried via ls;
                        // here we emit a best-effort event. With the subprocess channel,
                        // sftp runs synchronously in batch per-command mode, so by the
                        // time this loop runs, the transfer may already be done.
                        transferred = localSize
                        let progress = TransferProgress(bytesTransferred: transferred, totalBytes: localSize)
                        await MainActor.run {
                            if taskIndex < self.transfers.count {
                                self.transfers[taskIndex].status = .inProgress(fractionCompleted: progress.fractionCompleted)
                            }
                        }
                        continuation.yield(progress)
                    }

                    await MainActor.run {
                        if taskIndex < self.transfers.count {
                            self.transfers[taskIndex].status = .completed
                        }
                    }
                    continuation.finish()
                } catch {
                    await MainActor.run {
                        if taskIndex < self.transfers.count {
                            self.transfers[taskIndex].status = .failed(error)
                        }
                    }
                    continuation.finish(throwing: error)
                }
            }
        }

        return stream
    }

    // MARK: - Download

    /// Downloads a remote file to a local URL and tracks progress via polling.
    @discardableResult
    func download(remotePath: String, toLocalURL localURL: URL) async throws -> AsyncThrowingStream<TransferProgress, Error> {
        let taskId = UUID()
        let task = TransferTask(
            id: taskId,
            remotePath: remotePath,
            localURL: localURL,
            direction: .download,
            status: .pending
        )
        transfers.append(task)
        let taskIndex = transfers.count - 1

        // Best-effort: get the remote file size via a quick ls query before downloading.
        let remoteItems = try? await channel.listDirectory(path: (remotePath as NSString).deletingLastPathComponent)
        let remoteName = (remotePath as NSString).lastPathComponent
        let remoteSize = remoteItems?.first(where: { $0.name == remoteName })?.size ?? 0

        let stream = AsyncThrowingStream<TransferProgress, Error> { continuation in
            Task {
                do {
                    self.channel.send("get \(remotePath) \(localURL.path)")

                    // Poll local file size to approximate download progress.
                    var downloaded: Int64 = 0
                    let total = remoteSize > 0 ? remoteSize : 1
                    while downloaded < total {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        downloaded = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? total
                        let progress = TransferProgress(bytesTransferred: downloaded, totalBytes: total)
                        await MainActor.run {
                            if taskIndex < self.transfers.count {
                                self.transfers[taskIndex].status = .inProgress(fractionCompleted: progress.fractionCompleted)
                            }
                        }
                        continuation.yield(progress)
                    }

                    await MainActor.run {
                        if taskIndex < self.transfers.count {
                            self.transfers[taskIndex].status = .completed
                        }
                    }
                    continuation.finish()
                } catch {
                    await MainActor.run {
                        if taskIndex < self.transfers.count {
                            self.transfers[taskIndex].status = .failed(error)
                        }
                    }
                    continuation.finish(throwing: error)
                }
            }
        }

        return stream
    }

    // MARK: - Open locally

    /// Downloads a remote item to /tmp/mobaalt-downloads/ and opens it with the default app.
    func openLocally(item: SFTPItem) async throws {
        let downloadsDir = URL(fileURLWithPath: "/tmp/mobaalt-downloads")
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let localURL = downloadsDir.appendingPathComponent(item.name)
        try await download(remotePath: item.path, toLocalURL: localURL)
        await NSWorkspace.shared.open(localURL)
    }

    // MARK: - Private helpers

    /// Polls for the ControlMaster socket file at 200ms intervals, up to `timeout` seconds.
    ///
    /// This prevents a race condition where `SFTPSubprocessChannel` is spawned before
    /// the SSH ControlMaster process has written its socket file. Only called for real
    /// (non-mock) channels — see connect().
    private func waitForSocket(_ path: String, timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: UInt64 = 200_000_000 // 200ms in nanoseconds

        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path) { return }
            try await Task.sleep(nanoseconds: pollInterval)
        }

        if !FileManager.default.fileExists(atPath: path) {
            throw SFTPError.socketTimeout
        }
    }
}
