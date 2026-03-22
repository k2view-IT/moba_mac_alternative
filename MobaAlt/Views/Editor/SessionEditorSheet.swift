import SwiftUI

struct SessionEditorSheet: View {
    var session: SessionDefinition?
    var targetFolderId: UUID?

    @Environment(SessionLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SessionDefinition
    @State private var selectedTab = 0
    @State private var showingWizard = false
    /// Password owned here; loaded from Keychain on appear, written on save.
    @State private var sessionPassword: String = ""
    @State private var savePasswordToKeychain: Bool = true

    init(session: SessionDefinition?, targetFolderId: UUID?) {
        self.session = session
        self.targetFolderId = targetFolderId
        if let session {
            _draft = State(initialValue: session)
        } else {
            _draft = State(initialValue: SessionDefinition(
                name: "",
                folderId: targetFolderId,
                protocolConfig: .ssh(SSHConfig(hostname: "")),
                sortOrder: 0
            ))
        }
    }

    private var isCreating: Bool { session == nil }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet toolbar
            HStack {
                Text(isCreating ? "New Session" : "Edit Session")
                    .font(.headline)
                Spacer()
                Button("Wizard") {
                    showingWizard = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            TabView(selection: $selectedTab) {
                SessionEditorBasicTab(
                    draft: $draft,
                    password: $sessionPassword,
                    saveToKeychain: $savePasswordToKeychain
                )
                .tabItem { Label("Basic", systemImage: "info.circle") }
                .tag(0)

                SessionEditorAdvancedTab(draft: $draft)
                    .tabItem { Label("Advanced", systemImage: "gearshape") }
                    .tag(1)

                if case .ssh(var sshConfig) = draft.protocolConfig {
                    PortForwardingEditorView(rules: Binding(
                        get: {
                            if case .ssh(let c) = draft.protocolConfig { return c.portForwardingRules }
                            return []
                        },
                        set: { newRules in
                            if case .ssh(var c) = draft.protocolConfig {
                                c.portForwardingRules = newRules
                                draft.protocolConfig = .ssh(c)
                            }
                        }
                    ))
                    .tabItem { Label("Tunnels", systemImage: "arrow.left.arrow.right.circle") }
                    .tag(2)
                    .onAppear { _ = sshConfig }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            // Bottom action buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isCreating ? "Create" : "Save") {
                    saveAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 460)
        .sheet(isPresented: $showingWizard) {
            SessionWizardView(draft: $draft)
        }
        .task {
            // When editing an existing session, pre-fill the password field from Keychain.
            if let session {
                sessionPassword = (try? await KeychainManager().getPassword(for: session.id)) ?? ""
            }
        }
    }

    private func saveAndDismiss() {
        guard !draft.name.isEmpty else { return }
        if isCreating {
            var newSession = draft
            newSession = SessionDefinition(
                id: newSession.id,
                name: newSession.name,
                folderId: newSession.folderId ?? targetFolderId,
                protocolConfig: newSession.protocolConfig,
                notes: newSession.notes,
                sortOrder: library.sessions.count,
                createdAt: newSession.createdAt
            )
            library.addSession(newSession)
        } else {
            library.updateSession(draft)
        }
        // Persist password to Keychain if requested
        if savePasswordToKeychain && !sessionPassword.isEmpty {
            let sessionId = draft.id
            let pw = sessionPassword
            Task {
                try? await KeychainManager().savePassword(pw, for: sessionId)
            }
        }
        dismiss()
    }
}
