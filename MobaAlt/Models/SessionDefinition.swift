import Foundation

/// A single saved remote session (SSH, RDP, or VNC).
///
/// Credentials are NEVER stored here.
/// Credential stored in Keychain keyed by session.id.uuidString.
struct SessionDefinition: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderId: UUID?              // nil = root level
    var protocolConfig: ConnectionProtocol
    var notes: String = ""           // optional notes (used in HTML export and editor Advanced tab)
    var sortOrder: Int               // explicit ordering — NEVER rely on array index
    var createdAt: Date
    var lastConnected: Date?

    init(
        id: UUID = UUID(),
        name: String,
        folderId: UUID? = nil,
        protocolConfig: ConnectionProtocol,
        notes: String = "",
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.folderId = folderId
        self.protocolConfig = protocolConfig
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lastConnected = lastConnected
    }
}
