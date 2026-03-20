import Foundation

// MARK: - HTML Exporter

/// Generates an HTML summary page from sessions and folders.
/// All user-provided strings are HTML-escaped.
/// Passwords and SSH keys are never included.
struct HTMLExporter {

    // MARK: - Public API

    /// Exports sessions and folders to a well-formed UTF-8 HTML string.
    func export(sessions: [SessionDefinition], folders: [SessionFolder]) -> String {
        let folderById = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        let exportDate = ISO8601DateFormatter().string(from: Date())

        var rows = ""
        for session in sessions.sorted(by: { $0.name < $1.name }) {
            let folderPath = buildFolderPath(for: session.folderId, folderById: folderById)
            let proto = session.protocolConfig.protocolName
            let host = htmlEscape(session.protocolConfig.hostname)
            let port = session.protocolConfig.port
            let name = htmlEscape(session.name)
            let folder = htmlEscape(folderPath)
            let notes = htmlEscape(session.notes)

            rows += """
                    <tr>
                        <td>\(proto)</td>
                        <td>\(name)</td>
                        <td>\(host)</td>
                        <td>\(port)</td>
                        <td>\(folder)</td>
                        <td>\(notes)</td>
                    </tr>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>MobaAlt Session Export</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem; color: #333; }
                h1 { font-size: 1.5rem; margin-bottom: 0.25rem; }
                .meta { color: #666; font-size: 0.875rem; margin-bottom: 1.5rem; }
                table { border-collapse: collapse; width: 100%; font-size: 0.9rem; }
                th { background: #f0f0f0; text-align: left; padding: 0.5rem 0.75rem; border-bottom: 2px solid #ddd; }
                td { padding: 0.4rem 0.75rem; border-bottom: 1px solid #eee; }
                tr:hover td { background: #fafafa; }
                .note { color: #666; font-style: italic; }
            </style>
        </head>
        <body>
            <h1>MobaAlt — Session Export</h1>
            <p class="meta">Exported: \(exportDate) &middot; \(sessions.count) session(s)</p>
            <table>
                <thead>
                    <tr>
                        <th>Type</th>
                        <th>Name</th>
                        <th>Host</th>
                        <th>Port</th>
                        <th>Folder</th>
                        <th>Notes</th>
                    </tr>
                </thead>
                <tbody>
        \(rows)        </tbody>
            </table>
        </body>
        </html>
        """
    }

    // MARK: - Private Helpers

    private func buildFolderPath(for folderId: UUID?, folderById: [UUID: SessionFolder]) -> String {
        guard let folderId = folderId, let folder = folderById[folderId] else {
            return ""
        }
        let parentPath = buildFolderPath(for: folder.parentId, folderById: folderById)
        return parentPath.isEmpty ? folder.name : "\(parentPath) / \(folder.name)"
    }

    private func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
