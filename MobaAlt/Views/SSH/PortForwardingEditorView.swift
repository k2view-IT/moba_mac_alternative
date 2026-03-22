import SwiftUI

/// Inline view for managing a list of PortForwardingRule entries.
/// Designed to be embedded as a tab inside SessionEditorSheet.
struct PortForwardingEditorView: View {

    @Binding var rules: [PortForwardingRule]

    @State private var showingAddForm = false
    @State private var newDirection: ForwardingDirection = .local
    @State private var newLocalPortText = ""
    @State private var newRemotePortText = ""

    var body: some View {
        VStack(spacing: 0) {
            if rules.isEmpty {
                emptyState
            } else {
                rulesList
            }

            Divider()

            addButton
        }
        .sheet(isPresented: $showingAddForm) {
            addRuleSheet
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No port forwarding rules")
                .foregroundStyle(.secondary)
            Text("Press \"Add Rule\" to forward ports over this SSH connection.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulesList: some View {
        List {
            ForEach(rules) { rule in
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
            .onDelete { offsets in
                rules.remove(atOffsets: offsets)
            }
        }
    }

    private var addButton: some View {
        HStack {
            Spacer()
            Button {
                newDirection = .local
                newLocalPortText = ""
                newRemotePortText = ""
                showingAddForm = true
            } label: {
                Label("Add Rule", systemImage: "plus.circle")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var addRuleSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Forwarding Rule")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Form {
                Picker("Direction", selection: $newDirection) {
                    ForEach(ForwardingDirection.allCases, id: \.self) { dir in
                        Text(dir.rawValue.capitalized).tag(dir)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Local Port", text: $newLocalPortText)

                if newDirection != .dynamic {
                    TextField("Remote Port", text: $newRemotePortText)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    showingAddForm = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    commitNewRule()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360, height: 280)
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        guard let localPort = Int(newLocalPortText), localPort > 0, localPort <= 65535 else {
            return false
        }
        if newDirection != .dynamic {
            guard let remotePort = Int(newRemotePortText), remotePort > 0, remotePort <= 65535 else {
                return false
            }
        }
        return true
    }

    private func commitNewRule() {
        guard let localPort = Int(newLocalPortText) else { return }
        let remotePort = Int(newRemotePortText) ?? 0
        let rule = PortForwardingRule(
            direction: newDirection,
            localPort: localPort,
            remotePort: remotePort
        )
        rules.append(rule)
        showingAddForm = false
    }

    private func directionIcon(for direction: ForwardingDirection) -> String {
        switch direction {
        case .local:   return "arrow.right.circle"
        case .remote:  return "arrow.left.circle"
        case .dynamic: return "circle.grid.cross"
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
