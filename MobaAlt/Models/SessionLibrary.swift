import Foundation
import Observation

/// In-memory session and folder store. The single source of truth for the UI.
///
/// Every mutation calls `onMutation` (defaults to no-op) so callers can
/// wire in persistence without coupling the library to a specific store.
@Observable
final class SessionLibrary {
    var sessions: [SessionDefinition] = []
    var folders: [SessionFolder] = []

    /// Called after every mutation. Wire to SessionStore.save in MobaAltApp.
    var onMutation: () async -> Void = {}

    // MARK: - Session CRUD

    func addSession(_ session: SessionDefinition) {
        sessions.append(session)
        triggerSave()
    }

    func updateSession(_ session: SessionDefinition) {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[idx] = session
        triggerSave()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        triggerSave()
    }

    // MARK: - Folder CRUD

    func addFolder(_ folder: SessionFolder) {
        folders.append(folder)
        triggerSave()
    }

    func updateFolder(_ folder: SessionFolder) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx] = folder
        triggerSave()
    }

    /// Delete a folder and recursively delete all child sessions and subfolders.
    func deleteFolder(id: UUID) {
        deleteSubtree(folderId: id)
        folders.removeAll { $0.id == id }
        triggerSave()
    }

    // MARK: - Query

    /// Returns sessions in the specified folder (nil = root), sorted by sortOrder ascending.
    func sessions(inFolder folderId: UUID?) -> [SessionDefinition] {
        sessions
            .filter { $0.folderId == folderId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Returns direct subfolders of the given parent (nil = root), sorted by sortOrder ascending.
    func subfolders(of parentId: UUID?) -> [SessionFolder] {
        folders
            .filter { $0.parentId == parentId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Returns sessions whose name or hostname contains `query` (case-insensitive).
    /// Returns all sessions when query is empty.
    func search(query: String) -> [SessionDefinition] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { session in
            session.name.localizedCaseInsensitiveContains(query)
                || session.protocolConfig.hostname.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Private Helpers

    /// Recursively deletes all sessions and subfolders within the given folder.
    private func deleteSubtree(folderId: UUID) {
        let children = folders.filter { $0.parentId == folderId }
        for child in children {
            deleteSubtree(folderId: child.id)
            folders.removeAll { $0.id == child.id }
        }
        sessions.removeAll { $0.folderId == folderId }
    }

    private func triggerSave() {
        let mutation = onMutation
        Task { await mutation() }
    }
}
