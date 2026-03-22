import SwiftUI

struct ContentView: View {
    @State private var searchQuery = ""
    @State private var selectedSessionId: UUID?
    @State private var showingEditor = false
    @State private var editorSession: SessionDefinition?
    @State private var editorTargetFolderId: UUID?
    @State private var tabManager = TabManager()
    @State private var showingKeyVault = false
    @State private var showingSnippets = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                searchQuery: $searchQuery,
                selectedSessionId: $selectedSessionId,
                showingEditor: $showingEditor,
                editorSession: $editorSession,
                editorTargetFolderId: $editorTargetFolderId
            )
            .navigationSplitViewColumnWidth(min: 150, ideal: 220, max: 400)
        } detail: {
            if tabManager.tabs.isEmpty {
                Text("Select a session to connect")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    TerminalTabBar(tabManager: tabManager)
                    Divider()
                    if let activeTab = tabManager.tabs.first(where: { $0.id == tabManager.activeTabId }) {
                        TerminalTabView(connection: activeTab.connection)
                            .id(activeTab.id)
                    }
                }
            }
        }
        .environment(tabManager)
        .searchable(text: $searchQuery, placement: .sidebar, prompt: "Search sessions")
        .sheet(isPresented: $showingEditor) {
            SessionEditorSheet(
                session: editorSession,
                targetFolderId: editorTargetFolderId
            )
        }
        .sheet(isPresented: $showingKeyVault) {
            KeyVaultView()
        }
        .sheet(isPresented: $showingSnippets) {
            CommandSnippetsView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingKeyVault = true
                } label: {
                    Label("SSH Key Vault", systemImage: "person.badge.key")
                }
                .help("Manage SSH Key Vault")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSnippets = true
                } label: {
                    Label("Command Snippets", systemImage: "text.alignleft")
                }
                .help("Show command snippet library")
            }
        }
    }
}
