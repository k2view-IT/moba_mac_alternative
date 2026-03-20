import Foundation

/// Swift actor for crash-safe, atomic JSON persistence of sessions and folders.
///
/// Files are stored at ~/Library/Application Support/MobaAlt/:
///   - sessions.json  — array of SessionDefinition
///   - folders.json   — array of SessionFolder
///
/// Before each save, existing files are backed up (.backup extension).
/// On load failure, the backup is attempted; on backup failure, empty arrays are returned.
actor SessionStore {
    let appSupportURL: URL
    let sessionsURL: URL
    let foldersURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MobaAlt")

        appSupportURL = base
        sessionsURL = base.appendingPathComponent("sessions.json")
        foldersURL = base.appendingPathComponent("folders.json")

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec

        // Create the Application Support directory if it does not exist
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    /// Initialiser that accepts a custom directory URL — used by tests to avoid
    /// polluting the real Application Support folder.
    init(directory: URL) {
        appSupportURL = directory
        sessionsURL = directory.appendingPathComponent("sessions.json")
        foldersURL = directory.appendingPathComponent("folders.json")

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// Saves sessions and folders atomically.
    /// Makes a .backup copy of each file before overwriting.
    func save(sessions: [SessionDefinition], folders: [SessionFolder]) throws {
        let fm = FileManager.default

        // Backup existing sessions file
        if fm.fileExists(atPath: sessionsURL.path) {
            let backup = sessionsURL.appendingPathExtension("backup")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: sessionsURL, to: backup)
        }

        // Backup existing folders file
        if fm.fileExists(atPath: foldersURL.path) {
            let backup = foldersURL.appendingPathExtension("backup")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: foldersURL, to: backup)
        }

        // Write sessions atomically
        let sessionsData = try encoder.encode(sessions)
        try atomicWrite(sessionsData, to: sessionsURL)

        // Write folders atomically
        let foldersData = try encoder.encode(folders)
        try atomicWrite(foldersData, to: foldersURL)
    }

    // MARK: - Load

    /// Loads sessions and folders from disk.
    /// If files don't exist, returns ([], []).
    /// On decode error, attempts to load from backup; on backup failure, returns ([], []).
    func load() throws -> (sessions: [SessionDefinition], folders: [SessionFolder]) {
        let sessions = loadFile(url: sessionsURL, type: [SessionDefinition].self)
        let folders = loadFile(url: foldersURL, type: [SessionFolder].self)
        return (sessions, folders)
    }

    // MARK: - Private

    private func loadFile<T: Decodable>(url: URL, type: T.Type) -> T where T: ExpressibleByArrayLiteral, T.ArrayLiteralElement: Decodable {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[SessionStore] Failed to load \(url.lastPathComponent): \(error) — attempting backup")
            let backup = url.appendingPathExtension("backup")
            guard FileManager.default.fileExists(atPath: backup.path) else {
                print("[SessionStore] No backup found for \(url.lastPathComponent) — returning empty")
                return []
            }
            do {
                let data = try Data(contentsOf: backup)
                return try decoder.decode(T.self, from: data)
            } catch {
                print("[SessionStore] Backup load also failed for \(url.lastPathComponent): \(error) — returning empty")
                return []
            }
        }
    }
}
