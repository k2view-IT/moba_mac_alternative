import SwiftUI

struct SessionEditorAdvancedTab: View {
    @Binding var draft: SessionDefinition

    @Environment(SessionLibrary.self) private var library

    var body: some View {
        Form {
            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if draft.notes.isEmpty {
                            Text("Optional notes about this session...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Organization") {
                Picker("Folder", selection: $draft.folderId) {
                    Text("Root (no folder)").tag(Optional<UUID>.none)
                    ForEach(flatFolderList) { item in
                        Text(item.indentedName).tag(Optional(item.folder.id))
                    }
                }
            }

            Section("Port Forwarding") {
                Text("Available in Phase 2")
                    .foregroundStyle(.secondary)
            }

            Section("Logging") {
                Text("Available in Phase 2")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Flat folder list with depth indentation

    private struct FlatFolderItem: Identifiable {
        var id: UUID { folder.id }
        let folder: SessionFolder
        let depth: Int
        var indentedName: String {
            String(repeating: "  ", count: depth) + folder.name
        }
    }

    private var flatFolderList: [FlatFolderItem] {
        var result: [FlatFolderItem] = []
        appendFolders(parentId: nil, depth: 0, into: &result)
        return result
    }

    private func appendFolders(parentId: UUID?, depth: Int, into result: inout [FlatFolderItem]) {
        for folder in library.subfolders(of: parentId) {
            result.append(FlatFolderItem(folder: folder, depth: depth))
            appendFolders(parentId: folder.id, depth: depth + 1, into: &result)
        }
    }
}
