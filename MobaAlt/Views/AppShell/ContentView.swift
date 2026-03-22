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
                detailBody
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard let activeTab = tabManager.tabs.first(where: { $0.id == tabManager.activeTabId }) else { return }
                    let positions: [SFTPPanelPosition] = SFTPPanelPosition.allCases
                    let current = activeTab.sftpPosition
                    let next = positions[(positions.firstIndex(of: current)! + 1) % positions.count]
                    tabManager.setSFTPPosition(next, for: activeTab.id)
                } label: {
                    Label("SFTP Panel", systemImage: sftpToolbarIcon)
                }
                .help("Toggle SFTP Panel position (Left / Right / Bottom / Hidden)")
            }
        }
    }

    // MARK: - Detail body

    /// The terminal stack: tab bar + active terminal view.
    @ViewBuilder
    private var terminalStack: some View {
        VStack(spacing: 0) {
            TerminalTabBar(tabManager: tabManager)
            Divider()
            if let activeTab = tabManager.tabs.first(where: { $0.id == tabManager.activeTabId }) {
                TerminalTabView(connection: activeTab.connection)
                    .id(activeTab.id)
            }
        }
    }

    /// Full detail area with optional SFTP panel based on active tab's sftpPosition.
    @ViewBuilder
    private var detailBody: some View {
        if let activeTab = tabManager.tabs.first(where: { $0.id == tabManager.activeTabId }) {
            switch activeTab.sftpPosition {
            case .left:
                HSplitView {
                    SFTPPanelView(service: activeTab.sftpService)
                        .frame(minWidth: 180, idealWidth: 280, maxWidth: 500)
                    terminalStack
                }
            case .right:
                HSplitView {
                    terminalStack
                    SFTPPanelView(service: activeTab.sftpService)
                        .frame(minWidth: 180, idealWidth: 280, maxWidth: 500)
                }
            case .bottom:
                VSplitView {
                    terminalStack
                    SFTPPanelView(service: activeTab.sftpService)
                        .frame(minHeight: 150, idealHeight: 260, maxHeight: 500)
                }
            case .hidden:
                terminalStack
            }
        } else {
            terminalStack
        }
    }

    // MARK: - SFTP toolbar icon

    private var sftpToolbarIcon: String {
        guard let activeTab = tabManager.tabs.first(where: { $0.id == tabManager.activeTabId }) else {
            return "sidebar.leading"
        }
        switch activeTab.sftpPosition {
        case .left:   return "sidebar.leading"
        case .right:  return "sidebar.trailing"
        case .bottom: return "rectangle.bottomthird.inset.filled"
        case .hidden: return "xmark.rectangle"
        }
    }
}

