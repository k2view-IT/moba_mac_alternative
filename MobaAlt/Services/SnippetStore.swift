import Foundation

// MARK: - SnippetStore

/// An @Observable store for [CommandSnippet] with JSON persistence.
///
/// Snippets are stored at:
///   ~/Library/Application Support/MobaAlt/snippets.json
///
/// Must be used on the main actor (all mutations happen via async tasks that
/// return to MainActor).
@Observable
@MainActor
final class SnippetStore {

    // MARK: - Properties

    private(set) var snippets: [CommandSnippet] = []

    private let fileURL: URL

    // MARK: - Initialization

    /// Designated initializer — uses the provided directory (for test isolation).
    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("snippets.json")
    }

    /// Convenience initializer for production use.
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = appSupport.appendingPathComponent("MobaAlt", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("snippets.json")
    }

    // MARK: - Public API

    /// Loads snippets from disk. Non-fatal if the file doesn't exist yet.
    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        snippets = try JSONDecoder().decode([CommandSnippet].self, from: data)
    }

    /// Appends a new snippet and persists the updated list.
    func add(_ snippet: CommandSnippet) throws {
        snippets.append(snippet)
        try save()
    }

    /// Removes the snippet with the given id and persists.
    func remove(id: UUID) throws {
        snippets.removeAll { $0.id == id }
        try save()
    }

    /// Replaces an existing snippet with the same id and persists.
    func update(_ snippet: CommandSnippet) throws {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        try save()
    }

    // MARK: - Private

    private func save() throws {
        let data = try JSONEncoder().encode(snippets)
        // Ensure directory exists before writing.
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Atomic write via a temp file.
        let tempURL = directory.appendingPathComponent("snippets.json.tmp")
        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
    }
}
