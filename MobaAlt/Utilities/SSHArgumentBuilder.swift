import Foundation

/// Pure value-type builder that converts an SSHConfig into an argv array
/// suitable for passing to LocalProcessTerminalView.startProcess(args:).
struct SSHArgumentBuilder {

    // MARK: - Public API

    /// Builds the argv array for /usr/bin/ssh from an SSHConfig and a session UUID.
    ///
    /// - Parameters:
    ///   - config: The SSH configuration to build arguments from.
    ///   - sessionId: The session UUID, used to derive the ControlMaster socket path.
    /// - Returns: An array of argument strings (not including the executable itself).
    static func build(from config: SSHConfig, sessionId: UUID) -> [String] {
        var args: [String] = []

        // Non-default port
        if config.port != 22 {
            args += ["-p", "\(config.port)"]
        }

        // Username
        if !config.username.isEmpty {
            args += ["-l", config.username]
        }

        // Auth method
        switch config.authMethod {
        case .privateKey:
            if !config.privateKeyPath.isEmpty {
                args += ["-i", config.privateKeyPath]
            }
        case .agent:
            args.append("-A")
        case .password:
            break
        }

        // Agent forwarding (separate from auth method)
        if config.agentForwarding && config.authMethod != .agent {
            args.append("-A")
        }

        // X11 forwarding
        if config.x11Forwarding {
            args.append("-X")
        }

        // Port forwarding rules
        for rule in config.portForwardingRules {
            switch rule.direction {
            case .local:
                args += ["-L", "\(rule.localPort):localhost:\(rule.remotePort)"]
            case .remote:
                args += ["-R", "\(rule.remotePort):localhost:\(rule.localPort)"]
            case .dynamic:
                args += ["-D", "\(rule.localPort)"]
            }
        }

        // ControlMaster — always enabled for SFTP multiplexing (Phase 3)
        args += ["-o", "ControlMaster=auto"]
        args += ["-o", "ControlPath=\(controlPath(for: sessionId))"]
        args += ["-o", "ControlPersist=no"]

        // Hostname must be the last argument
        args.append(config.hostname)

        return args
    }

    /// Returns the ControlMaster Unix socket path for a given session UUID.
    ///
    /// Uses only the first 8 hex characters of the UUID to stay well under the
    /// macOS 104-character Unix socket path length limit.
    static func controlPath(for sessionId: UUID) -> String {
        let prefix = String(sessionId.uuidString.prefix(8)).lowercased()
        return "/tmp/mobaalt-\(prefix).sock"
    }

    /// Returns the environment array (KEY=VALUE strings) for the SSH process.
    ///
    /// Always sets TERM=xterm-256color and LANG=en_US.UTF-8.
    /// Inherits SSH_AUTH_SOCK from the parent process environment if present.
    ///
    /// - Parameter base: The environment dictionary to inherit from (defaults to current process env).
    /// - Returns: An array of "KEY=VALUE" strings.
    static func environment(
        inheritingFrom base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        var env: [String] = []

        env.append("TERM=xterm-256color")
        env.append("LANG=en_US.UTF-8")

        if let authSock = base["SSH_AUTH_SOCK"] {
            env.append("SSH_AUTH_SOCK=\(authSock)")
        }

        return env
    }
}
