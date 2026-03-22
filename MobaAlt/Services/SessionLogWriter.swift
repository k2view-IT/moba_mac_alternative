import Foundation

/// Actor that writes terminal session output bytes to a log file.
///
/// Log files are stored in ~/Library/Application Support/MobaAlt/Logs/
/// Named as {sessionId}-{ISO8601 date}.log
actor SessionLogWriter {

    // MARK: - Properties

    private var fileHandle: FileHandle?

    // MARK: - Initializer

    /// Opens (or creates) a log file at the given URL for writing.
    /// - Throws: An error if the FileHandle cannot be opened.
    init(logFileURL: URL) throws {
        // Ensure the parent directory exists
        let dir = logFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        self.fileHandle = try FileHandle(forWritingTo: logFileURL)
        // Seek to end in case the file already had content
        try self.fileHandle?.seekToEnd()
    }

    // MARK: - Public API

    /// Writes a slice of bytes to the log file.
    func write(_ bytes: ArraySlice<UInt8>) {
        guard let handle = fileHandle else { return }
        let data = Data(bytes)
        handle.write(data)
    }

    /// Closes the underlying file handle.
    func close() {
        try? fileHandle?.close()
        fileHandle = nil
    }

    // MARK: - Static Factory

    /// Creates a log file URL for a given session ID using today's date.
    static func logFileURL(for sessionId: UUID) -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let logsDir = appSupport
            .appendingPathComponent("MobaAlt", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateStr = formatter.string(from: Date())

        let filename = "\(sessionId.uuidString)-\(dateStr).log"
        return logsDir.appendingPathComponent(filename)
    }
}
