import SwiftUI

struct SessionWizardView: View {
    @Binding var draft: SessionDefinition
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionLibrary.self) private var library

    @State private var currentStep = 0
    @State private var selectedProtocol: WizardProtocolType = .ssh
    @State private var hostname = ""
    @State private var port = 22
    @State private var username = ""
    @State private var authMethod: SSHAuthMethod = .password
    @State private var saveToKeychain = true

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("Session Wizard")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Step indicator dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 12)

            // Step content
            Group {
                switch currentStep {
                case 0: typeStep
                case 1: connectionStep
                case 2: authStep
                case 3: optionsStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)

            Divider()

            // Navigation buttons
            HStack {
                Button("Back") { currentStep -= 1 }
                    .disabled(currentStep == 0)
                Spacer()
                Button(currentStep == totalSteps - 1 ? "Finish" : "Next") {
                    if currentStep == totalSteps - 1 {
                        applyAndDismiss()
                    } else {
                        currentStep += 1
                        // Initialize port when moving to connection step
                        if currentStep == 1 {
                            port = selectedProtocol.defaultPort
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 360)
    }

    // MARK: - Steps

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 1: Choose a connection type")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(WizardProtocolType.allCases) { type in
                protocolTypeButton(type)
            }
        }
    }

    @ViewBuilder
    private func protocolTypeButton(_ type: WizardProtocolType) -> some View {
        let isSelected = selectedProtocol == type
        Button(action: { selectedProtocol = type }) {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(type.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .fontWeight(.semibold)
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var connectionStep: some View {
        Form {
            Section("Step 2: Connection Details") {
                TextField("Hostname", text: $hostname)
                    .onChange(of: hostname) { _, newValue in
                        if draft.name.isEmpty || draft.name == hostname {
                            draft.name = newValue
                        }
                    }
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", value: $port, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                if selectedProtocol != .vnc {
                    TextField("Username", text: $username)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var authStep: some View {
        Form {
            Section("Step 3: Authentication") {
                if selectedProtocol == .ssh {
                    Picker("Method", selection: $authMethod) {
                        ForEach(SSHAuthMethod.allCases, id: \.self) { method in
                            Text(method.wizardDisplayName).tag(method)
                        }
                    }
                } else {
                    SecureField("Password", text: .constant(""))
                        .disabled(true)
                        .overlay(alignment: .trailing) {
                            Text("Keychain in Phase 2")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.trailing, 4)
                        }
                    Toggle("Save to Keychain", isOn: $saveToKeychain)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var optionsStep: some View {
        Form {
            Section("Step 4: Options") {
                TextField("Session Name", text: $draft.name)
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 60)
                    .overlay(alignment: .topLeading) {
                        if draft.notes.isEmpty {
                            Text("Notes (optional)...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                Picker("Folder", selection: $draft.folderId) {
                    Text("Root (no folder)").tag(Optional<UUID>.none)
                    ForEach(library.folders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Finish

    private func applyAndDismiss() {
        switch selectedProtocol {
        case .ssh:
            draft.protocolConfig = .ssh(SSHConfig(
                hostname: hostname,
                port: port,
                username: username,
                authMethod: authMethod
            ))
        case .rdp:
            draft.protocolConfig = .rdp(RDPConfig(
                hostname: hostname,
                port: port,
                username: username
            ))
        case .vnc:
            draft.protocolConfig = .vnc(VNCConfig(hostname: hostname, port: port))
        }
        if draft.name.isEmpty {
            draft.name = hostname.isEmpty ? "New Session" : hostname
        }
        dismiss()
    }
}

// MARK: - Wizard Protocol Type

private enum WizardProtocolType: String, CaseIterable, Identifiable {
    case ssh = "SSH"
    case rdp = "RDP"
    case vnc = "VNC"

    var id: String { rawValue }

    var defaultPort: Int {
        switch self {
        case .ssh: return 22
        case .rdp: return 3389
        case .vnc: return 5900
        }
    }

    var iconName: String {
        switch self {
        case .ssh: return "terminal"
        case .rdp: return "desktopcomputer"
        case .vnc: return "eye"
        }
    }

    var color: Color {
        switch self {
        case .ssh: return .green
        case .rdp: return .blue
        case .vnc: return .orange
        }
    }

    var description: String {
        switch self {
        case .ssh: return "Secure Shell — terminal access to Linux/Unix servers"
        case .rdp: return "Remote Desktop — graphical access to Windows machines"
        case .vnc: return "Virtual Network Computing — graphical remote control"
        }
    }
}

private extension SSHAuthMethod {
    var wizardDisplayName: String {
        switch self {
        case .password: return "Password"
        case .privateKey: return "Private Key File"
        case .agent: return "SSH Agent"
        }
    }
}
