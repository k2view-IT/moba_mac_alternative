import Foundation

// MARK: - Session Conflict

/// Represents a naming conflict between an incoming and an existing session.
struct SessionConflict {
    /// The session being imported.
    let incoming: SessionDefinition
    /// The session already in the library that conflicts.
    let existing: SessionDefinition
}

// MARK: - Conflict Resolver

/// Detects naming conflicts during import and provides auto-rename capability.
struct SessionConflictResolver {

    /// Returns all conflicts where an incoming session has the same name (case-insensitive)
    /// and is in the same folder (or both root-level) as an existing session.
    func findConflicts(
        incoming: [SessionDefinition],
        existing: [SessionDefinition]
    ) -> [SessionConflict] {
        incoming.compactMap { incomingSession in
            let match = existing.first { existingSession in
                existingSession.name.lowercased() == incomingSession.name.lowercased()
                    && existingSession.folderId == incomingSession.folderId
            }
            return match.map { SessionConflict(incoming: incomingSession, existing: $0) }
        }
    }

    /// Returns a copy of `session` with a unique name that doesn't appear in `existingNames`.
    /// Appends " (2)", " (3)", etc. until a unique name is found.
    func rename(_ session: SessionDefinition, avoiding existingNames: [String]) -> SessionDefinition {
        let lowerExisting = Set(existingNames.map { $0.lowercased() })
        var candidate = session
        var suffix = 2

        while lowerExisting.contains(candidate.name.lowercased()) {
            candidate.name = "\(session.name) (\(suffix))"
            suffix += 1
        }

        return candidate
    }
}
