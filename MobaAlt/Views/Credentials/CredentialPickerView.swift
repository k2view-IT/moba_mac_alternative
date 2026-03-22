import SwiftUI

// MARK: - CredentialPickerView

/// An inline view embedded in SessionEditorSheet for configuring SSH authentication.
///
/// Supports three auth methods:
/// - password: SecureField that persists to Keychain
/// - privateKey: Picker of vault key names (stored in SSHConfig.privateKeyPath)
/// - agent: Informational — uses SSH_AUTH_SOCK from shell environment
struct CredentialPickerView: View {
    @Binding var authMethod: SSHAuthMethod
    @Binding var privateKeyPath: String
    let sessionId: UUID

    @Environment(\.keyVaultManager) private var vaultManager
    @Environment(\.keychainManager) private var keychainManager

    @State private var password = ""
    @State private var availableKeyNames: [String] = []
    @State private var showingUnlockSheet = false
    @State private var isVaultUnlocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Auth method picker
            Picker("Authentication", selection: $authMethod) {
                Text("Password").tag(SSHAuthMethod.password)
                Text("SSH Key").tag(SSHAuthMethod.privateKey)
                Text("SSH Agent").tag(SSHAuthMethod.agent)
            }
            .pickerStyle(.segmented)

            // Method-specific controls
            switch authMethod {
            case .password:
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: password) { _, newValue in
                        savePassword(newValue)
                    }

            case .privateKey:
                if isVaultUnlocked {
                    if availableKeyNames.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("No SSH keys in vault. Add keys via SSH Key Vault in the toolbar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("SSH Key", selection: $privateKeyPath) {
                            Text("Select a key...").tag("")
                            ForEach(availableKeyNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                        Text("Vault locked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Unlock...") {
                            showingUnlockSheet = true
                        }
                        .font(.caption)
                    }
                }

            case .agent:
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Uses SSH_AUTH_SOCK from your shell environment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingUnlockSheet) {
            KeyVaultUnlockView(
                onUnlocked: {
                    showingUnlockSheet = false
                    isVaultUnlocked = true
                    loadKeyNames()
                },
                onCancel: {
                    showingUnlockSheet = false
                }
            )
        }
        .onAppear {
            loadCurrentPassword()
            Task {
                isVaultUnlocked = await vaultManager.isUnlocked
                if isVaultUnlocked {
                    loadKeyNames()
                }
            }
        }
        .onChange(of: authMethod) { _, _ in
            if authMethod == .privateKey && isVaultUnlocked {
                loadKeyNames()
            }
        }
    }

    // MARK: - Private helpers

    private func loadCurrentPassword() {
        Task {
            guard let stored = try? await keychainManager.getPassword(for: sessionId) else { return }
            await MainActor.run {
                password = stored
            }
        }
    }

    private func savePassword(_ newPassword: String) {
        Task {
            try? await keychainManager.savePassword(newPassword, for: sessionId)
        }
    }

    private func loadKeyNames() {
        Task {
            guard let names = try? await vaultManager.listKeyNames() else { return }
            await MainActor.run {
                availableKeyNames = names.sorted()
            }
        }
    }
}
