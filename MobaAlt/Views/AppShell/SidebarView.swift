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
    @State private var showingExport = false
    @State private var exportFolderId: UUID? = nil
    @State private var showingImport = false
    @State private var importURL: URL? = nil
    @State private var isDragTarget = false

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
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragTarget) { providers in
            // Accept dropped .mxtsessions files
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url,
                              url.pathExtension.lowercased() == "mxtsessions" else { return }
                        DispatchQueue.main.async {
                            importURL = url
                            showingImport = true
                        }
                    }
                    return true
                }
            }
            return false
        }
        .overlay {
            if isDragTarget {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.blue, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
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
            Button("Import Sessions…") {
                importURL = nil
                showingImport = true
            }
            Button("Export…") {
                exportFolderId = nil
                showingExport = true
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
            ToolbarItem(placement: .automatic) {
                Button(action: { exportFolderId = nil; showingExport = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export sessions…")
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportDialogSheet(initialFolderId: exportFolderId)
        }
        .sheet(isPresented: $showingImport) {
            ImportWizardSheet(preloadedURL: importURL)
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
                    showingExport: $showingExport,
                    exportFolderId: $exportFolderId,
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
