import Foundation

/// Represents a remote file or directory entry on an SFTP server.
struct SFTPItem: Identifiable, Equatable, Hashable, Sendable {
    /// Uses path as stable identity across directory listings.
    var id: String { path }

    let name: String
    let path: String
    let size: Int64
    let modificationDate: Date
    let isDirectory: Bool
    let permissions: String

    /// Placeholder for future symlink support — always false until Phase 3 symlink plan.
    var isSymlink: Bool { false }
}
