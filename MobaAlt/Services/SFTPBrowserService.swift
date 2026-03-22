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
        lastCommand = "delete \(path)"
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

    // MARK: Init

    /// Designated init — inject a channel for testing or custom transport.
    init(channel: SFTPChannel, sessionId: UUID) {
        self.channel = channel
        self.sessionId = sessionId
    }

    /// Convenience production init.
    /// TODO: 03-02 replaces MockSFTPChannel with SFTPSubprocessChannel once that class exists.
    convenience init(sessionId: UUID) {
        self.init(channel: MockSFTPChannel(), sessionId: sessionId)
    }

    // MARK: Connection

    func connect() async throws {
        try await channel.connect()
        isConnected = true
    }

    func listDirectory(path: String) async throws {
        isLoading = true
        defer { isLoading = false }
        items = try await channel.listDirectory(path: path)
        currentPath = path
    }

    // MARK: File operations (stubs — implemented in 03-02+)

    func upload(localURL: URL, toRemotePath remotePath: String) async throws {
        fatalError("Not yet implemented — see Plan 03-02")
    }

    func download(remotePath: String, toLocalURL localURL: URL) async throws {
        fatalError("Not yet implemented — see Plan 03-02")
    }

    func createDirectory(at path: String) async throws {
        fatalError("Not yet implemented — see Plan 03-02")
    }

    func rename(from: String, to: String) async throws {
        fatalError("Not yet implemented — see Plan 03-02")
    }

    func delete(at path: String) async throws {
        fatalError("Not yet implemented — see Plan 03-02")
    }
}
