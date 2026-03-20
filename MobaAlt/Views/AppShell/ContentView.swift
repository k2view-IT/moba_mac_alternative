import SwiftUI

struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchQuery = ""
    @State private var selectedSessionId: UUID?
    @State private var showingEditor = false
    @State private var editorSession: SessionDefinition?
    @State private var editorTargetFolderId: UUID?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                searchQuery: $searchQuery,
                selectedSessionId: $selectedSessionId,
                showingEditor: $showingEditor,
                editorSession: $editorSession,
                editorTargetFolderId: $editorTargetFolderId
            )
            .navigationSplitViewColumnWidth(min: 150, ideal: 220, max: 400)
        } detail: {
            Text("Select a session to connect")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $searchQuery, placement: .sidebar, prompt: "Search sessions")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .help("Toggle Sidebar (Cmd+Shift+L)")
            }
        }
        .sheet(isPresented: $showingEditor) {
            SessionEditorSheet(
                session: editorSession,
                targetFolderId: editorTargetFolderId
            )
        }
    }

    private func toggleSidebar() {
        withAnimation {
            if columnVisibility == .all {
                columnVisibility = .detailOnly
            } else {
                columnVisibility = .all
            }
        }
    }
}
