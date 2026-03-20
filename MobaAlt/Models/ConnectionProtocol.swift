import Foundation

// MARK: - SSH Auth Method

enum SSHAuthMethod: String, Codable, Hashable, CaseIterable {
    case password
    case privateKey   // path stored in SSHConfig.privateKeyPath
    case agent
}

// MARK: - Protocol Configs

struct SSHConfig: Codable, Hashable {
    var hostname: String
    var port: Int = 22
    var username: String = ""
    var authMethod: SSHAuthMethod = .password
    var privateKeyPath: String = ""   // used when authMethod == .privateKey
    var x11Forwarding: Bool = false
    var agentForwarding: Bool = false
}

struct RDPConfig: Codable, Hashable {
    var hostname: String
    var port: Int = 3389
    var username: String = ""
    var domain: String = ""
}

struct VNCConfig: Codable, Hashable {
    var hostname: String
    var port: Int = 5900
}

// MARK: - ConnectionProtocol

/// Discriminated union of supported remote connection protocols.
/// JSON shape: {"type": "ssh", "config": {...}} for forward-compatibility.
enum ConnectionProtocol: Codable, Hashable {
    case ssh(SSHConfig)
    case rdp(RDPConfig)
    case vnc(VNCConfig)

    // MARK: Computed Properties

    var protocolName: String {
        switch self {
        case .ssh: return "SSH"
        case .rdp: return "RDP"
        case .vnc: return "VNC"
        }
    }

    var hostname: String {
        switch self {
        case .ssh(let c): return c.hostname
        case .rdp(let c): return c.hostname
        case .vnc(let c): return c.hostname
        }
    }

    var port: Int {
        switch self {
        case .ssh(let c): return c.port
        case .rdp(let c): return c.port
        case .vnc(let c): return c.port
        }
    }

    // MARK: Codable — custom discriminator {"type":"ssh","config":{...}}

    private enum CodingKeys: String, CodingKey {
        case type
        case config
    }

    private enum ProtocolType: String, Codable {
        case ssh, rdp, vnc
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(ProtocolType.self, forKey: .type)
        switch type_ {
        case .ssh:
            let config = try container.decode(SSHConfig.self, forKey: .config)
            self = .ssh(config)
        case .rdp:
            let config = try container.decode(RDPConfig.self, forKey: .config)
            self = .rdp(config)
        case .vnc:
            let config = try container.decode(VNCConfig.self, forKey: .config)
            self = .vnc(config)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ssh(let config):
            try container.encode(ProtocolType.ssh, forKey: .type)
            try container.encode(config, forKey: .config)
        case .rdp(let config):
            try container.encode(ProtocolType.rdp, forKey: .type)
            try container.encode(config, forKey: .config)
        case .vnc(let config):
            try container.encode(ProtocolType.vnc, forKey: .type)
            try container.encode(config, forKey: .config)
        }
    }
}
