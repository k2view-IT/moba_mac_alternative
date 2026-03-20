import SwiftUI
import UniformTypeIdentifiers

struct FolderRowView: View {
    let folder: SessionFolder
    @Binding var selectedSessionId: UUID?
    @Binding var renamingFolderId: UUID?
    @Binding var showingExport: Bool
    @Binding var exportFolderId: UUID?
    var onNewSession: (UUID?) -> Void
    var onEditSession: (SessionDefinition) -> Void

    @Environment(SessionLibrary.self) private var library
    @State private var renameText = ""

    private var isRenaming: Bool { renamingFolderId == folder.id }

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { folder.isExpanded },
            set: { newValue in
                var updated = folder
                updated.isExpanded = newValue
                library.updateFolder(updated)
            }
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpandedBinding) {
            // Recursive subfolders
            ForEach(library.subfolders(of: folder.id)) { subfolder in
                FolderRowView(
                    folder: subfolder,
                    selectedSessionId: $selectedSessionId,
                    renamingFolderId: $renamingFolderId,
                    showingExport: $showingExport,
                    exportFolderId: $exportFolderId,
                    onNewSession: onNewSession,
                    onEditSession: onEditSession
                )
            }
            // Sessions in this folder
            ForEach(library.sessions(inFolder: folder.id)) { session in
                SessionRowView(
                    session: session,
                    selectedSessionId: $selectedSessionId,
                    onEdit: { onEditSession(session) },
                    onConnect: { print("[Phase 1] Connect: \(session.name)") }
                )
                .padding(.leading, 8)
                .tag(session.id)
            }
        } label: {
            if isRenaming {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color(nsColor: .systemYellow))
                    TextField("Folder name", text: $renameText)
                        .textFieldStyle(.plain)
                        .onSubmit { commitRename() }
                        .onExitCommand { renamingFolderId = nil }
                        .onAppear { renameText = folder.name }
                }
            } else {
                Label(folder.name, systemImage: "folder.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .labelStyle(FolderLabelStyle())
            }
        }
        .onDrop(
            of: [UTType.plainText],
            delegate: FolderDropDelegate(targetFolderId: folder.id, library: library)
        )
        .contextMenu {
            Button("New Session in Folder") {
                onNewSession(folder.id)
            }
            Button("Rename Folder") {
                renameText = folder.name
                renamingFolderId = folder.id
            }
            Button("Export Folder…") {
                exportFolderId = folder.id
                showingExport = true
            }
            Divider()
            Button("Delete Folder", role: .destructive) {
                library.deleteFolder(id: folder.id)
            }
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            var updated = folder
            updated.name = trimmed
            library.updateFolder(updated)
        }
        renamingFolderId = nil
    }
}

/// Custom label style that tints the folder icon in the macOS system gold color.
private struct FolderLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .foregroundStyle(Color(nsColor: .systemYellow))
            configuration.title
        }
    }
}
