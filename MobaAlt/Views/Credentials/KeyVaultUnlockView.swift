import SwiftUI

// MARK: - KeyVaultUnlockView

/// A modal sheet for entering the master password to unlock the SSH key vault.
///
/// Presented when an SSH session requires key auth but the vault is locked.
struct KeyVaultUnlockView: View {
    @Environment(\.keyVaultManager) private var vaultManager
    @State private var masterPassword = ""
    @State private var unlockError: String?
    @State private var isUnlocking = false

    var onUnlocked: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("SSH Key Vault")
                    .font(.headline)
            }
            .padding(.top, 8)

            Text("Enter your master password to unlock the SSH key vault.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Master Password", text: $masterPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    performUnlock()
                }

            if let errorMessage = unlockError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Unlock") {
                    performUnlock()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(masterPassword.isEmpty || isUnlocking)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }

    private func performUnlock() {
        guard !masterPassword.isEmpty else { return }
        isUnlocking = true
        unlockError = nil

        Task {
            do {
                try await vaultManager.unlock(masterPassword: masterPassword)
                await MainActor.run {
                    isUnlocking = false
                    onUnlocked()
                }
            } catch VaultError.wrongPassword {
                await MainActor.run {
                    isUnlocking = false
                    unlockError = "Incorrect master password. Please try again."
                }
            } catch {
                await MainActor.run {
                    isUnlocking = false
                    unlockError = "Failed to unlock vault: \(error.localizedDescription)"
                }
            }
        }
    }
}
