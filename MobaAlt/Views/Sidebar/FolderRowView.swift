import SwiftUI
import UniformTypeIdentifiers

struct FolderRowView: View {
    let folder: SessionFolder
    @Binding var selectedSessionId: UUID?
    var onNewSession: (UUID?) -> Void
    var onEditSession: (SessionDefinition) -> Void

    @Environment(SessionLibrary.self) private var library

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
            }
        } label: {
            Label(folder.name, systemImage: "folder.fill")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .labelStyle(FolderLabelStyle())
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
                // Phase 1 placeholder — inline rename not yet implemented
            }
            Button("Delete Folder", role: .destructive) {
                library.deleteFolder(id: folder.id)
            }
            Button("Export this Folder") {
                // Placeholder — implemented in plan 01-03
            }
        }
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
