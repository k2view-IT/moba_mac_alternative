import Foundation

// MARK: - JSON Exporter

/// Exports sessions + folders as pretty-printed JSON.
/// Passwords and SSH keys are NEVER included — SessionDefinition does not contain passwords by design.
struct JSONExporter {

    // MARK: - Export Container

    /// Top-level JSON structure.
    private struct ExportContainer: Encodable {
        let version: String = "1.0"
        let exportedAt: Date
        let sessions: [SessionDefinition]
        let folders: [SessionFolder]
    }

    // MARK: - Public API

    /// Exports sessions and folders to pretty-printed, sorted-keys JSON Data (UTF-8 encoded).
    func export(sessions: [SessionDefinition], folders: [SessionFolder]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let container = ExportContainer(
            exportedAt: Date(),
            sessions: sessions,
            folders: folders
        )

        return try encoder.encode(container)
    }
}
