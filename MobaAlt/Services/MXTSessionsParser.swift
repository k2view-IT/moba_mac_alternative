import Foundation

// MARK: - Parse Result

/// The result of parsing a .mxtsessions file.
struct MXTParseResult {
    /// All parsed folders with parentId set by SubRep path hierarchy.
    var folders: [SessionFolder]
    /// Parsed sessions with their associated folder ID (nil = root).
    var sessions: [(folderId: UUID?, session: SessionDefinition)]
    /// Descriptions of malformed lines that were skipped.
    var errors: [String]
}

// MARK: - Parse Error

enum MXTParseError: Error, LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Could not decode .mxtsessions file as Windows-1252 or UTF-8"
        }
    }
}

// MARK: - Parser

/// Parses MobaXterm .mxtsessions INI format into SessionDefinition + SessionFolder arrays.
struct MXTSessionsParser {

    // MARK: - Special encoding sequences

    private static let specialDecodings: [(from: String, to: String)] = [
        ("__PTVIRG__", ";"),
        ("__DBLQUO__", "\""),
        ("__PIPE__",   "|"),
        ("__DIEZE__",  "#"),
        ("__PERCENT__", "%"),
        ("_CurrentDrive_", "C:"),
    ]

    // MARK: - Public API

    func parse(data: Data) throws -> MXTParseResult {
        // 1. Decode: Windows-1252 first, fallback to UTF-8
        guard let raw = String(data: data, encoding: .windowsCP1252)
                ?? String(data: data, encoding: .utf8) else {
            throw MXTParseError.invalidEncoding
        }

        // 2. Normalize line endings
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")

        // 3. Split into sections
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var sections: [(name: String, lines: [String])] = []
        var currentSectionName = ""
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[Bookmarks") && trimmed.hasSuffix("]") {
                if !currentSectionName.isEmpty || !currentLines.isEmpty {
                    sections.append((name: currentSectionName, lines: currentLines))
                }
                currentSectionName = trimmed
                currentLines = []
            } else {
                currentLines.append(trimmed)
            }
        }
        if !currentSectionName.isEmpty || !currentLines.isEmpty {
            sections.append((name: currentSectionName, lines: currentLines))
        }

        // 4. Process sections: build folders and sessions
        var foldersByPath: [String: SessionFolder] = [:]  // path -> folder
        var resultFolders: [SessionFolder] = []
        var resultSessions: [(folderId: UUID?, session: SessionDefinition)] = []
        var parseErrors: [String] = []
        var sessionIndex = 0

        for section in sections {
            // Extract SubRep value
            let subRepLine = section.lines.first { $0.hasPrefix("SubRep=") }
            let subRepRaw = subRepLine.map { String($0.dropFirst("SubRep=".count)) } ?? ""
            let subRepPath = subRepRaw.trimmingCharacters(in: .whitespaces)

            // Resolve the folder for this section
            let folderId: UUID? = subRepPath.isEmpty
                ? nil
                : ensureFolder(path: subRepPath, foldersByPath: &foldersByPath, resultFolders: &resultFolders)

            // Parse session lines
            for line in section.lines {
                // Skip section meta lines
                if line.hasPrefix("SubRep=") || line.hasPrefix("ImgNum=")
                    || line.isEmpty || line.hasPrefix("[") {
                    continue
                }

                // Session line: Name=Value where Value starts with #
                guard let eqRange = line.range(of: "=") else { continue }
                let rawName = String(line[line.startIndex..<eqRange.lowerBound])
                let value = String(line[eqRange.upperBound...])

                guard value.hasPrefix("#") else { continue }

                let sessionName = decodeSpecial(rawName)
                guard !sessionName.isEmpty else { continue }

                // Parse session value: #iconNum#group1#group2#tabMode#comments#tabColor
                let parts = value.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
                // parts[0] is empty (before first #), parts[1]=iconNum, parts[2]=group1...
                // Actual format after leading # split:
                // [0]="" [1]=iconNum [2]=group1 [3]=group2 [4]=tabMode [5]=comments [6]=tabColor
                let group1 = parts.count > 2 ? parts[2] : ""
                let comments = parts.count > 5 ? decodeSpecial(parts[5]) : ""

                // Split group1 by %
                let fields = group1.split(separator: "%", omittingEmptySubsequences: false).map(String.init)
                let typeCode = Int(fields[safe: 0] ?? "") ?? -1

                let protocolConfig: ConnectionProtocol
                switch typeCode {
                case 0:
                    // SSH: type%host%port%user%...%x11(field 5)%...%privkey(field 14)
                    let hostname = decodeSpecial(fields[safe: 1] ?? "")
                    let port = Int(fields[safe: 2] ?? "") ?? 22
                    let username = decodeSpecial(fields[safe: 3] ?? "")
                    let x11Raw = fields[safe: 5] ?? ""
                    let x11 = x11Raw == "-1"
                    let privKey = decodeSpecial(fields[safe: 14] ?? "")
                    protocolConfig = .ssh(SSHConfig(
                        hostname: hostname,
                        port: port,
                        username: username,
                        authMethod: privKey.isEmpty ? .password : .privateKey,
                        privateKeyPath: privKey,
                        x11Forwarding: x11
                    ))
                case 1, 4:
                    // RDP: MobaXterm uses type code 1 in practice (some docs show 4 — accept both)
                    let hostname = decodeSpecial(fields[safe: 1] ?? "")
                    let port = Int(fields[safe: 2] ?? "") ?? 3389
                    protocolConfig = .rdp(RDPConfig(hostname: hostname, port: port))
                case 5:
                    // VNC: type%host%port%...
                    let hostname = decodeSpecial(fields[safe: 1] ?? "")
                    let port = Int(fields[safe: 2] ?? "") ?? 5900
                    protocolConfig = .vnc(VNCConfig(hostname: hostname, port: port))
                default:
                    // Try heuristic: if first field is empty (typeCode == -1) and looks like host:port,
                    // treat as VNC. The sample has "DB Monitor=#98#%10.0.0.10%5900%%" — empty type.
                    if typeCode == -1, let hostField = fields[safe: 1], !hostField.isEmpty {
                        let hostname = decodeSpecial(hostField)
                        let port = Int(fields[safe: 2] ?? "") ?? 5900
                        protocolConfig = .vnc(VNCConfig(hostname: hostname, port: port))
                    } else {
                        parseErrors.append("Skipped session '\(sessionName)': unknown type code \(typeCode)")
                        continue
                    }
                }

                let session = SessionDefinition(
                    name: sessionName,
                    folderId: folderId,
                    protocolConfig: protocolConfig,
                    notes: comments,
                    sortOrder: sessionIndex
                )
                resultSessions.append((folderId: folderId, session: session))
                sessionIndex += 1
            }
        }

        return MXTParseResult(
            folders: resultFolders,
            sessions: resultSessions,
            errors: parseErrors
        )
    }

    // MARK: - Private Helpers

    /// Ensures the folder hierarchy for a given SubRep path exists, creating folders as needed.
    /// Returns the UUID of the deepest folder.
    @discardableResult
    private func ensureFolder(
        path: String,
        foldersByPath: inout [String: SessionFolder],
        resultFolders: inout [SessionFolder]
    ) -> UUID {
        if let existing = foldersByPath[path] {
            return existing.id
        }

        // Split path into components (separator is backslash)
        let components = path.split(separator: "\\").map(String.init)

        var parentId: UUID? = nil
        var currentPath = ""

        for (index, component) in components.enumerated() {
            if index > 0 { currentPath += "\\" }
            currentPath += component

            if let existing = foldersByPath[currentPath] {
                parentId = existing.id
            } else {
                let sortOrder = resultFolders.filter { $0.parentId == parentId }.count
                let folder = SessionFolder(
                    name: component,
                    parentId: parentId,
                    sortOrder: sortOrder
                )
                foldersByPath[currentPath] = folder
                resultFolders.append(folder)
                parentId = folder.id
            }
        }

        return parentId! // safe: we always have at least one component
    }

    /// Replaces MobaXterm special encoding sequences with their literal characters.
    private func decodeSpecial(_ input: String) -> String {
        var result = input
        for (from, to) in Self.specialDecodings {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
