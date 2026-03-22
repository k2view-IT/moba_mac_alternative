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
/// Internally, the sftp process is launched in interactive mode so it presents the
/// "sftp> " prompt for each command. readUntilPrompt() accumulates stdout bytes until
/// the "sftp> " marker appears, letting us issue one command at a time and capture output.
///
/// stdout is read via readabilityHandler (non-blocking) rather than availableData (blocking)
/// to avoid freezing the Swift Concurrency cooperative thread pool.
final class SFTPSubprocessChannel: SFTPChannel, @unchecked Sendable {

    // MARK: - State

    private let socketPath: String
    private let username: String
    private let hostname: String

    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()

    /// Accumulates stdout bytes between readUntilPrompt calls.
    private var stdoutBuffer = Data()

    /// Protects pendingContinuation and bufferedChunks from concurrent access between
    /// the readabilityHandler dispatch queue and the async callers.
    private let lock = NSLock()
    private var pendingContinuation: CheckedContinuation<Data, Never>?
    private var bufferedChunks: [Data] = []

    // MARK: - Init

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
        process.standardInput  = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe
    }

    // MARK: - SFTPChannel

    func connect() async throws {
        // Install the readabilityHandler BEFORE launching the process so no bytes are missed.
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData  // blocking OK: this runs on a dedicated I/O thread
            self.lock.lock()
            if let cont = self.pendingContinuation {
                self.pendingContinuation = nil
                self.lock.unlock()
                cont.resume(returning: data)
            } else {
                self.bufferedChunks.append(data)
                self.lock.unlock()
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            throw SFTPError.connectionFailed("Process launch failed: \(error.localizedDescription)")
        }

        // Consume the startup banner and first "sftp> " prompt (up to 15 s).
        _ = try await readUntilPrompt(timeout: 15)
    }

    func disconnect() async {
        send("bye")
        try? await Task.sleep(nanoseconds: 200_000_000)
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        // Unblock any pending waiter with empty data (EOF signal).
        lock.lock()
        let cont = pendingContinuation
        pendingContinuation = nil
        lock.unlock()
        cont?.resume(returning: Data())
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

    // MARK: - Non-blocking output reading

    /// Waits for the next available chunk of stdout data from the readabilityHandler.
    /// Returns empty Data on EOF.
    private func nextChunk() async -> Data {
        lock.lock()
        if !bufferedChunks.isEmpty {
            let chunk = bufferedChunks.removeFirst()
            lock.unlock()
            return chunk
        }
        return await withCheckedContinuation { continuation in
            pendingContinuation = continuation
            lock.unlock()
        }
    }

    /// Reads stdout until the "sftp> " prompt appears (non-blocking).
    /// Returns everything printed before the prompt.
    private func readUntilPrompt(timeout: TimeInterval) async throws -> String {
        let promptMarker = Data("sftp> ".utf8)

        // Serve from existing buffer if the prompt is already there.
        if let range = stdoutBuffer.range(of: promptMarker) {
            let outputData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex ..< range.lowerBound)
            stdoutBuffer = Data(stdoutBuffer[range.upperBound...])
            return String(data: outputData, encoding: .utf8) ?? ""
        }

        return try await withThrowingTaskGroup(of: String.self) { group in
            // Reader task: accumulates chunks until the prompt appears.
            group.addTask { [self] in
                while true {
                    try Task.checkCancellation()
                    let chunk = await self.nextChunk()

                    if chunk.isEmpty {
                        // EOF — process exited before prompt appeared.
                        let result = String(data: self.stdoutBuffer, encoding: .utf8) ?? ""
                        self.stdoutBuffer = Data()
                        return result
                    }

                    self.stdoutBuffer.append(chunk)

                    if let range = self.stdoutBuffer.range(of: promptMarker) {
                        let outputData = self.stdoutBuffer.subdata(in: self.stdoutBuffer.startIndex ..< range.lowerBound)
                        self.stdoutBuffer = Data(self.stdoutBuffer[range.upperBound...])
                        return String(data: outputData, encoding: .utf8) ?? ""
                    }
                }
            }

            // Timeout task.
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SFTPError.commandFailed("Timed out waiting for sftp prompt")
            }

            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    // MARK: - ls output parsing

    private func parseLsOutput(_ output: String, basePath: String) -> [SFTPItem] {
        output.components(separatedBy: "\n").compactMap { parseLsLine($0, basePath: basePath) }
    }

    /// Parses a single Unix `ls -la` line into an SFTPItem.
    ///
    /// Expected format:
    /// `drwxr-xr-x  2 user group 4096 Jan  5 14:23 dirname`
    ///
    /// Returns nil for "." and ".." entries, header lines, or lines that don't parse.
    func parseLsLine(_ line: String, basePath: String) -> SFTPItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("total ") else { return nil }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard tokens.count >= 9 else { return nil }

        let permissions = tokens[0]
        guard permissions.count == 10 else { return nil }

        let isDirectory = permissions.hasPrefix("d")
        let size = Int64(tokens[4]) ?? 0
        let name = tokens[8...].joined(separator: " ")
        guard name != ".", name != ".." else { return nil }

        let modificationDate = parseDate(month: tokens[5], day: tokens[6], timeOrYear: tokens[7]) ?? Date(timeIntervalSince1970: 0)
        let normalizedBase = basePath.hasSuffix("/") ? basePath : basePath + "/"

        return SFTPItem(
            name: name,
            path: normalizedBase + name,
            size: size,
            modificationDate: modificationDate,
            isDirectory: isDirectory,
            permissions: permissions
        )
    }

    private func parseDate(month: String, day: String, timeOrYear: String) -> Date? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let dayPadded = day.count == 1 ? " \(day)" : day
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if timeOrYear.contains(":") {
            formatter.dateFormat = "MMM dd HH:mm yyyy"
            return formatter.date(from: "\(month) \(dayPadded) \(timeOrYear) \(currentYear)")
        } else {
            formatter.dateFormat = "MMM dd yyyy"
            return formatter.date(from: "\(month) \(dayPadded) \(timeOrYear)")
        }
    }
}
