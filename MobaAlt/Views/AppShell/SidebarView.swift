import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var searchQuery: String
    @Binding var selectedSessionId: UUID?
    @Binding var showingEditor: Bool
    @Binding var editorSession: SessionDefinition?
    @Binding var editorTargetFolderId: UUID?

    @Environment(SessionLibrary.self) private var library
    @State private var renamingFolderId: UUID?

    var body: some View {
        Group {
            if searchQuery.isEmpty {
                treeView
            } else {
                searchResultsView
            }
        }
        .onDrop(
            of: [UTType.plainText],
            delegate: FolderDropDelegate(targetFolderId: nil, library: library)
        )
        .contextMenu {
            Button("New Session") {
                openNewSession(folderId: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            Button("New Folder") {
                let nextOrder = library.folders.count
                let folder = SessionFolder(name: "New Folder", parentId: nil, sortOrder: nextOrder)
                library.addFolder(folder)
                renamingFolderId = folder.id
            }
            Divider()
            Button("Export All Sessions") {
                // Placeholder — wired in plan 01-03
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { openNewSession(folderId: nil) }) {
                    Label("New Session", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Session (Cmd+N)")
            }
        }
    }

    // MARK: - Sub-views

    private var treeView: some View {
        List(selection: $selectedSessionId) {
            // Root-level folders
            ForEach(library.subfolders(of: nil)) { folder in
                FolderRowView(
                    folder: folder,
                    selectedSessionId: $selectedSessionId,
                    renamingFolderId: $renamingFolderId,
                    onNewSession: { folderId in openNewSession(folderId: folderId) },
                    onEditSession: { session in openEditSession(session) }
                )
            }
            // Root-level sessions (folderId == nil)
            ForEach(library.sessions(inFolder: nil)) { session in
                SessionRowView(
                    session: session,
                    selectedSessionId: $selectedSessionId,
                    onEdit: { openEditSession(session) },
                    onConnect: { print("[Phase 1] Connect: \(session.name)") }
                )
            }
        }
        .listStyle(.sidebar)
    }

    private var searchResultsView: some View {
        List(selection: $selectedSessionId) {
            ForEach(library.search(query: searchQuery)) { session in
                SessionRowView(
                    session: session,
                    selectedSessionId: $selectedSessionId,
                    onEdit: { openEditSession(session) },
                    onConnect: { print("[Phase 1] Connect: \(session.name)") }
                )
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Helpers

    private func openNewSession(folderId: UUID?) {
        editorSession = nil
        editorTargetFolderId = folderId
        showingEditor = true
    }

    private func openEditSession(_ session: SessionDefinition) {
        editorSession = session
        editorTargetFolderId = session.folderId
        showingEditor = true
    }
}
