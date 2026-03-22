import SwiftUI

// MARK: - KeyVaultView

/// A sheet view for managing stored SSH keys in the encrypted vault.
///
/// Accessible from the toolbar button in ContentView.
/// Shows list of key names with delete support and key generation.
struct KeyVaultView: View {
    @Environment(\.keyVaultManager) private var vaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var keyNames: [String] = []
    @State private var showingUnlock = false
    @State private var showingKeyGen = false
    @State private var loadError: String?
    @State private var isUnlocked = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SSH Key Vault")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            if !isUnlocked {
                // Locked state
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Vault Locked")
                        .font(.headline)

                    Text("Unlock the vault to view and manage your SSH keys.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Unlock...") {
                        showingUnlock = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Unlocked state — show key list
                if keyNames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "key.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No SSH Keys")
                            .font(.headline)

                        Text("Generate a key pair to get started.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(keyNames, id: \.self) { name in
                            HStack {
                                Image(systemName: "key")
                                    .foregroundStyle(.secondary)
                                Text(name)
                                Spacer()
                            }
                        }
                        .onDelete { indexSet in
                            deleteKeys(at: indexSet)
                        }
                    }
                }

                Divider()

                // Bottom toolbar
                HStack {
                    if let errorMessage = loadError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Generate New Key...") {
                        showingKeyGen = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 400, height: 320)
        .sheet(isPresented: $showingUnlock) {
            KeyVaultUnlockView(
                onUnlocked: {
                    showingUnlock = false
                    isUnlocked = true
                    loadKeyNames()
                },
                onCancel: {
                    showingUnlock = false
                }
            )
        }
        .sheet(isPresented: $showingKeyGen) {
            KeyGenSheet(onGenerated: { loadKeyNames() })
        }
        .onAppear {
            Task {
                isUnlocked = await vaultManager.isUnlocked
                if isUnlocked {
                    loadKeyNames()
                }
            }
        }
    }

    private func loadKeyNames() {
        Task {
            do {
                let names = try await vaultManager.listKeyNames()
                await MainActor.run {
                    keyNames = names.sorted()
                    loadError = nil
                }
            } catch {
                await MainActor.run {
                    loadError = "Failed to load keys: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteKeys(at indexSet: IndexSet) {
        let namesToDelete = indexSet.map { keyNames[$0] }
        Task {
            for name in namesToDelete {
                do {
                    try await vaultManager.removeKey(name: name)
                } catch {
                    await MainActor.run {
                        loadError = "Failed to delete '\(name)': \(error.localizedDescription)"
                    }
                }
            }
            loadKeyNames()
        }
    }
}

// MARK: - KeyGenSheet

/// An inline sheet for generating a new ed25519 key pair into the vault.
private struct KeyGenSheet: View {
    @Environment(\.keyVaultManager) private var vaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var keyName = ""
    @State private var comment = ""
    @State private var isGenerating = false
    @State private var generationError: String?

    var onGenerated: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Generate New SSH Key")
                .font(.headline)
                .padding(.top, 8)

            Form {
                TextField("Key Name", text: $keyName)
                    .help("A unique name to identify this key in the vault")
                TextField("Comment (optional)", text: $comment)
                    .help("Embedded in the public key, e.g. user@hostname")
            }

            if let errorMessage = generationError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Generate") {
                    generateKey()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(keyName.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
            }
        }
        .padding(20)
        .frame(minWidth: 340)
    }

    private func generateKey() {
        let name = keyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isGenerating = true
        generationError = nil

        Task {
            do {
                try await SSHKeyGenerator.generate(
                    name: name,
                    comment: comment.isEmpty ? "\(name)@mobaalt" : comment,
                    into: vaultManager
                )
                await MainActor.run {
                    isGenerating = false
                    onGenerated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = "Key generation failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
