import Foundation

enum ForwardingDirection: String, Codable, Hashable, CaseIterable {
    case local
    case remote
    case dynamic
}

struct PortForwardingRule: Identifiable, Codable, Hashable {
    let id: UUID
    var direction: ForwardingDirection
    var localPort: Int
    var remotePort: Int  // ignored for dynamic (SOCKS proxy)

    init(id: UUID = UUID(), direction: ForwardingDirection, localPort: Int, remotePort: Int = 0) {
        self.id = id
        self.direction = direction
        self.localPort = localPort
        self.remotePort = remotePort
    }
}
