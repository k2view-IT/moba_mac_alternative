import Foundation

// MARK: - Writer

/// Serializes SessionDefinition + SessionFolder arrays to .mxtsessions INI format.
/// Passwords and SSH keys are NEVER written.
struct MXTSessionsWriter {

    // MARK: - Special encoding sequences (reverse of parser)

    private static let specialEncodings: [(from: String, to: String)] = [
        (";",  "__PTVIRG__"),
        ("\"", "__DBLQUO__"),
        ("|",  "__PIPE__"),
        ("#",  "__DIEZE__"),
        ("%",  "__PERCENT__"),
        ("C:", "_CurrentDrive_"),
    ]

    // MARK: - Public API

    /// Exports sessions and folders to .mxtsessions format Data.
    /// Throws if encoding to Windows-1252 fails (falls back to UTF-8).
    func export(sessions: [SessionDefinition], folders: [SessionFolder]) throws -> Data {
        let text = buildText(sessions: sessions, folders: folders)
        // Prefer Windows-1252 encoding for maximum compatibility
        if let data = text.data(using: .windowsCP1252) {
            return data
        }
        // Fallback to UTF-8
        guard let data = text.data(using: .utf8) else {
            throw NSError(domain: "MXTSessionsWriter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to encode output as UTF-8"])
        }
        return data
    }

    // MARK: - Private Helpers

    private func buildText(sessions: [SessionDefinition], folders: [SessionFolder]) -> String {
        // Build path map for folder ID -> SubRep path
        var pathMap: [UUID: String] = [:]
        buildPaths(folders: folders, pathMap: &pathMap)

        // Group sessions by folderId
        var sessionsByFolder: [UUID?: [SessionDefinition]] = [:]
        for session in sessions {
            sessionsByFolder[session.folderId, default: []].append(session)
        }

        var output = ""
        var sectionIndex = 0

        // Write root section [Bookmarks]
        let rootSessions = (sessionsByFolder[nil] ?? []).sorted { $0.sortOrder < $1.sortOrder }
        output += writeSection(name: "[Bookmarks]", subRep: "", sessions: rootSessions)
        sectionIndex += 1

        // Write one section per folder, sorted by path for deterministic output
        let sortedFolders = folders.sorted { (a, b) -> Bool in
            let pathA = pathMap[a.id] ?? a.name
            let pathB = pathMap[b.id] ?? b.name
            return pathA < pathB
        }

        for folder in sortedFolders {
            let folderSessions = (sessionsByFolder[folder.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
            let subRep = pathMap[folder.id] ?? folder.name
            let sectionName = "[Bookmarks_\(sectionIndex)]"
            output += writeSection(name: sectionName, subRep: subRep, sessions: folderSessions)
            sectionIndex += 1
        }

        return output
    }

    private func writeSection(name: String, subRep: String, sessions: [SessionDefinition]) -> String {
        var lines = [name, "SubRep=\(subRep)", "ImgNum=42"]
        for session in sessions {
            lines.append(writeSessionLine(session: session))
        }
        lines.append("") // blank line after section
        return lines.joined(separator: "\r\n")
    }

    private func writeSessionLine(session: SessionDefinition) -> String {
        let encodedName = encodeSpecial(session.name)
        let group1 = buildGroup1(for: session.protocolConfig)
        // Format: name=#109#group1##0#0#0#0#
        return "\(encodedName)=#109#\(group1)##0#0#0#0#"
    }

    private func buildGroup1(for proto: ConnectionProtocol) -> String {
        switch proto {
        case .ssh(let cfg):
            // type%host%port%user%empty%x11%...14 fields total
            let x11 = cfg.x11Forwarding ? "-1" : "0"
            let host = encodeSpecial(cfg.hostname)
            let user = encodeSpecial(cfg.username)
            // Pad to 22 fields to match MobaXterm format
            return "0%\(host)%\(cfg.port)%\(user)%-1%\(x11)%%%%%0%0%0%%%-1%0%0%0%%1080%%0%0%1"
        case .rdp(let cfg):
            let host = encodeSpecial(cfg.hostname)
            return "4%\(host)%\(cfg.port)%%%%%9%%0%1%%%%-1"
        case .vnc(let cfg):
            let host = encodeSpecial(cfg.hostname)
            return "5%\(host)%\(cfg.port)%%"
        }
    }

    /// Builds a path map: folder UUID -> "Parent\\Child" SubRep string
    private func buildPaths(folders: [SessionFolder], pathMap: inout [UUID: String]) {
        // Index folders by ID for efficient parent lookup
        let folderById: [UUID: SessionFolder] = Dictionary(
            uniqueKeysWithValues: folders.map { ($0.id, $0) }
        )

        for folder in folders {
            pathMap[folder.id] = buildPath(for: folder.id, folderById: folderById)
        }
    }

    private func buildPath(for folderId: UUID, folderById: [UUID: SessionFolder]) -> String {
        guard let folder = folderById[folderId] else { return "" }
        if let parentId = folder.parentId {
            let parentPath = buildPath(for: parentId, folderById: folderById)
            return parentPath.isEmpty ? folder.name : "\(parentPath)\\\(folder.name)"
        }
        return folder.name
    }

    /// Replaces special characters with MobaXterm encoding sequences.
    private func encodeSpecial(_ input: String) -> String {
        var result = input
        for (from, to) in Self.specialEncodings {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}
