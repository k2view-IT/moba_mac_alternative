import SwiftUI

/// Sheet that displays the port forwarding rules configured for an active SSH connection.
/// Presented from the terminal toolbar when the active tab has an SSH connection.
struct ActiveTunnelsView: View {

    let connection: SSHConnection

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Active Tunnels")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            content
        }
        .frame(width: 400, height: 320)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if case .ssh(let sshConfig) = connection.session.protocolConfig {
            if sshConfig.portForwardingRules.isEmpty {
                emptyState
            } else {
                rulesList(rules: sshConfig.portForwardingRules)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No active tunnels")
                .foregroundStyle(.secondary)
            Text("Add port forwarding rules in the session editor to create tunnels.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rulesList(rules: [PortForwardingRule]) -> some View {
        List(rules) { rule in
            HStack(spacing: 10) {
                Image(systemName: directionIcon(for: rule.direction))
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ruleTitle(for: rule))
                        .font(.system(.body, design: .monospaced))
                    Text(rule.direction.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Helpers

    private func directionIcon(for direction: ForwardingDirection) -> String {
        switch direction {
        case .local:   return "arrow.right.circle.fill"
        case .remote:  return "arrow.left.circle.fill"
        case .dynamic: return "circle.grid.cross.fill"
        }
    }

    private func ruleTitle(for rule: PortForwardingRule) -> String {
        switch rule.direction {
        case .dynamic:
            return "localhost:\(rule.localPort) (SOCKS)"
        case .local, .remote:
            return "localhost:\(rule.localPort) \u{2192} *:\(rule.remotePort)"
        }
    }
}
