import Foundation

// MARK: - SFTPError

enum SFTPError: Error, LocalizedError {
    case socketTimeout
    case connectionFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .socketTimeout:
            return "Timed out waiting for SSH control socket to appear."
        case .connectionFailed(let msg):
            return "SFTP connection failed: \(msg)"
        case .commandFailed(let msg):
            return "SFTP command failed: \(msg)"
        }
    }
}

// MARK: - SFTPSubprocessChannel

/// Real SFTP transport that spawns /usr/bin/sftp over an existing SSH ControlMaster socket.
///
/// The companion SFTPBrowserService.connect() waits for the ControlMaster socket before
/// constructing this object, so the socket is guaranteed to exist at init time.
///
/// Internally, the sftp process is launched without -b (batch mode flag) so that it
/// presents the "sftp> " prompt for each command. readUntilPrompt() accumulates stdout
/// bytes until the "sftp> " marker appears, letting us issue one command at a time and
/// capture its output.
final class SFTPSubprocessChannel: SFTPChannel, @unchecked Sendable {

    // MARK: - State

    private let socketPath: String
    private let username: String
    private let hostname: String

    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()

    private var stdoutBuffer = Data()

    // MARK: - Init

    /// Creates an SFTP channel over an existing ControlMaster socket.
    ///
    /// - Parameters:
    ///   - socketPath: Path to the Unix socket produced by SSHArgumentBuilder.controlPath(for:).
    ///   - config: The SSH configuration for the session (username, hostname).
    init(socketPath: String, config: SSHConfig) {
        self.socketPath = socketPath
        self.username = config.username
        self.hostname = config.hostname

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sftp")
        process.arguments = [
            "-o", "ControlMaster=no",
            "-o", "ControlPath=\(socketPath)",
            "\(config.username)@\(config.hostname)"
        ]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
    }

    // MARK: - SFTPChannel

    func connect() async throws {
        do {
            try process.run()
        } catch {
            throw SFTPError.connectionFailed("Process launch failed: \(error.localizedDescription)")
        }

        // Consume the startup banner + first "sftp> " prompt.
        let banner = try await readUntilPrompt(timeout: 15)
        if banner.isEmpty {
            throw SFTPError.connectionFailed("sftp process did not emit a ready prompt")
        }
    }

    func disconnect() async {
        send("bye")
        // Give the process a moment to shut down gracefully.
        try? await Task.sleep(nanoseconds: 200_000_000)
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()
    }

    func send(_ command: String) {
        guard process.isRunning else { return }
        let data = (command + "\n").data(using: .utf8) ?? Data()
        stdinPipe.fileHandleForWriting.write(data)
    }

    func listDirectory(path: String) async throws -> [SFTPItem] {
        send("ls -la \(path)")
        let output = try await readUntilPrompt(timeout: 10)
        return parseLsOutput(output, basePath: path)
    }

    func createDirectory(at path: String) async throws {
        send("mkdir \(path)")
        let output = try await readUntilPrompt(timeout: 10)
        if output.contains("Couldn't") || output.contains("Failed") || output.contains("Permission denied") {
            throw SFTPError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func rename(from: String, to: String) async throws {
        send("rename \(from) \(to)")
        let output = try await readUntilPrompt(timeout: 10)
        if output.contains("Couldn't") || output.contains("Failed") || output.contains("Permission denied") {
            throw SFTPError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func delete(at path: String) async throws {
        send("rm \(path)")
        let output = try await readUntilPrompt(timeout: 10)
        if output.contains("Couldn't") || output.contains("Failed") || output.contains("Permission denied") {
            throw SFTPError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Output reading

    /// Reads stdout until the "sftp> " prompt appears (indicating the previous command finished).
    /// Returns everything before the final prompt marker.
    private func readUntilPrompt(timeout: TimeInterval) async throws -> String {
        let promptMarker = Data("sftp> ".utf8)
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: UInt64 = 50_000_000 // 50ms

        while Date() < deadline {
            // Pull any available bytes from the pipe (non-blocking).
            let available = stdoutPipe.fileHandleForReading.availableData
            if !available.isEmpty {
                stdoutBuffer.append(available)
            }

            if let range = stdoutBuffer.range(of: promptMarker) {
                // Extract output up to (not including) the prompt.
                let outputData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<range.lowerBound)
                // Keep anything after the prompt in the buffer (should be empty normally).
                stdoutBuffer = Data(stdoutBuffer[range.upperBound...])
                return String(data: outputData, encoding: .utf8) ?? ""
            }

            // Process may have exited without a prompt (e.g., error).
            if !process.isRunning && stdoutBuffer.range(of: promptMarker) == nil {
                let remainder = String(data: stdoutBuffer, encoding: .utf8) ?? ""
                stdoutBuffer = Data()
                return remainder
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        throw SFTPError.commandFailed("Timed out waiting for sftp prompt")
    }

    // MARK: - ls output parsing

    private func parseLsOutput(_ output: String, basePath: String) -> [SFTPItem] {
        let lines = output.components(separatedBy: "\n")
        var results: [SFTPItem] = []
        for line in lines {
            if let item = parseLsLine(line, basePath: basePath) {
                results.append(item)
            }
        }
        return results
    }

    /// Parses a single Unix `ls -la` line into an SFTPItem.
    ///
    /// Expected format:
    /// `drwxr-xr-x  2 user group 4096 Jan  5 14:23 dirname`
    ///
    /// Returns nil for "." and ".." entries, header lines, or lines that don't parse.
    func parseLsLine(_ line: String, basePath: String) -> SFTPItem? {
        // Skip blank lines and total lines (e.g. "total 48")
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("total ") else { return nil }

        // Tokenise: permissions links owner group size month day time/year name
        // The name may contain spaces so we split the first 8 tokens conservatively.
        var tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard tokens.count >= 9 else { return nil }

        let permissions = tokens[0]
        guard permissions.count == 10 else { return nil }

        let isDirectory = permissions.hasPrefix("d")
        let sizeStr = tokens[4]
        let size = Int64(sizeStr) ?? 0

        // Month (index 5), Day (6), Time/Year (7), Name starts at index 8
        let month = tokens[5]
        let day = tokens[6]
        let timeOrYear = tokens[7]
        // Name: reconstruct from index 8 onwards (handles spaces in names)
        let name = tokens[8...].joined(separator: " ")

        guard name != ".", name != ".." else { return nil }

        let modificationDate = parseDate(month: month, day: day, timeOrYear: timeOrYear) ?? Date(timeIntervalSince1970: 0)

        let normalizedBase = basePath.hasSuffix("/") ? basePath : basePath + "/"
        let path = normalizedBase + name

        return SFTPItem(
            name: name,
            path: path,
            size: size,
            modificationDate: modificationDate,
            isDirectory: isDirectory,
            permissions: permissions
        )
    }

    private func parseDate(month: String, day: String, timeOrYear: String) -> Date? {
        // sftp ls -la outputs either "HH:mm" (current year) or "YYYY" (older files).
        let currentYear = Calendar.current.component(.year, from: Date())
        let dayPadded = day.count == 1 ? " \(day)" : day

        if timeOrYear.contains(":") {
            // Format: "MMM dd HH:mm" — assume current year
            let rawString = "\(month) \(dayPadded) \(timeOrYear) \(currentYear)"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM dd HH:mm yyyy"
            return formatter.date(from: rawString)
        } else {
            // Format: "MMM dd YYYY"
            let rawString = "\(month) \(dayPadded) \(timeOrYear)"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM dd yyyy"
            return formatter.date(from: rawString)
        }
    }
}
