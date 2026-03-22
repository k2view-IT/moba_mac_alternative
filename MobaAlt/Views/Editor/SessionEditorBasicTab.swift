import SwiftUI

struct SessionEditorBasicTab: View {
    @Binding var draft: SessionDefinition
    /// Live password value owned by SessionEditorSheet; written to Keychain on save.
    @Binding var password: String
    /// Whether to persist the password to Keychain on save.
    @Binding var saveToKeychain: Bool

    @State private var previousHostname = ""

    // MARK: - Derived protocol state

    private var protocolType: ProtocolType {
        switch draft.protocolConfig {
        case .ssh: return .ssh
        case .rdp: return .rdp
        case .vnc: return .vnc
        }
    }

    private var hostname: String {
        get { draft.protocolConfig.hostname }
    }

    private var port: Int {
        draft.protocolConfig.port
    }

    var body: some View {
        Form {
            Section("General") {
                TextField("Name", text: $draft.name)

                Picker("Type", selection: protocolTypeBinding) {
                    Text("SSH").tag(ProtocolType.ssh)
                    Text("RDP").tag(ProtocolType.rdp)
                    Text("VNC").tag(ProtocolType.vnc)
                }
                .pickerStyle(.segmented)
            }

            Section("Connection") {
                TextField("Hostname", text: hostnameBinding)
                    .onChange(of: hostnameBinding.wrappedValue) { _, newValue in
                        autoFillName(newHostname: newValue)
                    }

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", value: portBinding, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                if protocolType != .vnc {
                    TextField("Username", text: usernameBinding)
                }
            }

            Section("Authentication") {
                if protocolType == .ssh {
                    Picker("Auth Method", selection: sshAuthMethodBinding) {
                        ForEach(SSHAuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    if case .ssh(let config) = draft.protocolConfig, config.authMethod == .privateKey {
                        TextField("Private Key Path", text: privateKeyPathBinding)
                    }
                }

                SecureField("Password", text: $password)
                Toggle("Save to Keychain", isOn: $saveToKeychain)
                    .help("Password is saved to macOS Keychain and injected automatically on connect.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            previousHostname = hostname
        }
    }

    // MARK: - Auto-fill helper

    private func autoFillName(newHostname: String) {
        // Auto-fill name if it's empty or still matches the previous hostname
        if draft.name.isEmpty || draft.name == previousHostname {
            draft.name = newHostname
        }
        previousHostname = newHostname
    }

    // MARK: - Protocol type switching

    private var protocolTypeBinding: Binding<ProtocolType> {
        Binding(
            get: { protocolType },
            set: { newType in
                let currentHostname = draft.protocolConfig.hostname
                switch newType {
                case .ssh:
                    draft.protocolConfig = .ssh(SSHConfig(hostname: currentHostname))
                case .rdp:
                    draft.protocolConfig = .rdp(RDPConfig(hostname: currentHostname))
                case .vnc:
                    draft.protocolConfig = .vnc(VNCConfig(hostname: currentHostname))
                }
            }
        )
    }

    // MARK: - Field bindings

    private var hostnameBinding: Binding<String> {
        Binding(
            get: {
                switch draft.protocolConfig {
                case .ssh(let c): return c.hostname
                case .rdp(let c): return c.hostname
                case .vnc(let c): return c.hostname
                }
            },
            set: { newValue in
                switch draft.protocolConfig {
                case .ssh(var c): c.hostname = newValue; draft.protocolConfig = .ssh(c)
                case .rdp(var c): c.hostname = newValue; draft.protocolConfig = .rdp(c)
                case .vnc(var c): c.hostname = newValue; draft.protocolConfig = .vnc(c)
                }
            }
        )
    }

    private var portBinding: Binding<Int> {
        Binding(
            get: { draft.protocolConfig.port },
            set: { newValue in
                switch draft.protocolConfig {
                case .ssh(var c): c.port = newValue; draft.protocolConfig = .ssh(c)
                case .rdp(var c): c.port = newValue; draft.protocolConfig = .rdp(c)
                case .vnc(var c): c.port = newValue; draft.protocolConfig = .vnc(c)
                }
            }
        )
    }

    private var usernameBinding: Binding<String> {
        Binding(
            get: {
                switch draft.protocolConfig {
                case .ssh(let c): return c.username
                case .rdp(let c): return c.username
                case .vnc: return ""
                }
            },
            set: { newValue in
                switch draft.protocolConfig {
                case .ssh(var c): c.username = newValue; draft.protocolConfig = .ssh(c)
                case .rdp(var c): c.username = newValue; draft.protocolConfig = .rdp(c)
                case .vnc: break
                }
            }
        )
    }

    private var sshAuthMethodBinding: Binding<SSHAuthMethod> {
        Binding(
            get: {
                if case .ssh(let c) = draft.protocolConfig { return c.authMethod }
                return .password
            },
            set: { newMethod in
                if case .ssh(var c) = draft.protocolConfig {
                    c.authMethod = newMethod
                    draft.protocolConfig = .ssh(c)
                }
            }
        )
    }

    private var privateKeyPathBinding: Binding<String> {
        Binding(
            get: {
                if case .ssh(let c) = draft.protocolConfig { return c.privateKeyPath }
                return ""
            },
            set: { newPath in
                if case .ssh(var c) = draft.protocolConfig {
                    c.privateKeyPath = newPath
                    draft.protocolConfig = .ssh(c)
                }
            }
        )
    }


}

// MARK: - Helpers

private enum ProtocolType: Hashable {
    case ssh, rdp, vnc
}

private extension SSHAuthMethod {
    var displayName: String {
        switch self {
        case .password: return "Password"
        case .privateKey: return "Private Key"
        case .agent: return "SSH Agent"
        }
    }
}
