import SwiftUI
import AppKit

// MARK: - SFTPFileListView

/// Sortable, multi-select file list for the SFTP browser panel.
///
/// Displays columns for name, size, and modified date. Supports inline rename,
/// context menu operations, double-click navigation, and keyboard shortcuts.
struct SFTPFileListView: View {

    let service: SFTPBrowserService
    @Binding var sortColumn: SFTPSortColumn
    @Binding var sortAscending: Bool

    @State private var selection: Set<String> = []
    @State private var renamingItemId: String? = nil
    @State private var renameText: String = ""

    // MARK: - Sorted items

    private var sortedItems: [SFTPItem] {
        switch sortColumn {
        case .name:
            return service.items.sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return sortAscending
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        case .size:
            return service.items.sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return sortAscending ? $0.size < $1.size : $0.size > $1.size
            }
        case .date:
            return service.items.sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return sortAscending
                    ? $0.modificationDate < $1.modificationDate
                    : $0.modificationDate > $1.modificationDate
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            columnHeaderRow
            Divider()
            fileList
        }
    }

    // MARK: - Column headers

    @ViewBuilder
    private var columnHeaderRow: some View {
        HStack(spacing: 0) {
            columnHeaderButton(title: "Name", column: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
            columnHeaderButton(title: "Size", column: .size)
                .frame(width: 70, alignment: .trailing)
            columnHeaderButton(title: "Modified", column: .date)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func columnHeaderButton(title: String, column: SFTPSortColumn) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - File list

    @ViewBuilder
    private var fileList: some View {
        List(sortedItems, id: \.id, selection: $selection) { item in
            fileRow(for: item)
                .tag(item.id)
                .contextMenu {
                    contextMenuItems(for: item)
                }
        }
        .listStyle(.plain)
    }

    // MARK: - File row

    @ViewBuilder
    private func fileRow(for item: SFTPItem) -> some View {
        ZStack {
            // Drag source overlay (invisible, handles drag-to-Finder)
            SFTPFileRowView(item: item, service: service)
                .opacity(0.001)

            // Visible row content
            HStack(spacing: 4) {
                Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.name))
                    .foregroundStyle(item.isDirectory ? .yellow : .secondary)
                    .frame(width: 16)

                if renamingItemId == item.id {
                    // Inline rename text field
                    TextField("", text: $renameText)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                        .onSubmit {
                            commitRename(item: item)
                        }
                        .onExitCommand {
                            renamingItemId = nil
                        }
                } else {
                    Text(item.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                Text(item.isDirectory ? "--" : formatSize(item.size))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)

                Text(formatDate(item.modificationDate))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: 2).onEnded {
                    handleDoubleClick(item: item)
                }
            )
            .onKeyPress(.return) {
                if selection.contains(item.id) && renamingItemId == nil {
                    renamingItemId = item.id
                    renameText = item.name
                    return .handled
                }
                return .ignored
            }
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuItems(for item: SFTPItem) -> some View {
        Button("New File") {
            Task {
                try? await service.createDirectory(at: "\(service.currentPath)/NewFile.txt")
                try? await service.listDirectory(path: service.currentPath)
            }
        }
        Button("New Folder") {
            Task {
                try? await service.createDirectory(at: "\(service.currentPath)/NewFolder")
                try? await service.listDirectory(path: service.currentPath)
            }
        }
        Divider()
        Button("Rename") {
            renamingItemId = item.id
            renameText = item.name
        }
        Button("Delete", role: .destructive) {
            Task {
                let targets = selection.isEmpty ? [item.path] : Array(selection)
                for path in targets {
                    try? await service.delete(at: path)
                }
                try? await service.listDirectory(path: service.currentPath)
            }
        }
        Divider()
        if selection.count > 1 {
            Button("Download \(selection.count) Items") {
                batchDownloadWithPanel()
            }
        } else {
            Button("Download") {
                downloadWithPanel(item: item)
            }
        }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        }
    }

    // MARK: - Actions

    private func handleDoubleClick(item: SFTPItem) {
        if item.isDirectory {
            Task { try? await service.listDirectory(path: item.path) }
        } else {
            Task { try? await service.openLocally(item: item) }
        }
    }

    private func commitRename(item: SFTPItem) {
        let dir = (item.path as NSString).deletingLastPathComponent
        let newPath = dir + "/" + renameText
        Task {
            try? await service.rename(from: item.path, to: newPath)
            try? await service.listDirectory(path: service.currentPath)
        }
        renamingItemId = nil
    }

    private func downloadWithPanel(item: SFTPItem) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.name
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                try? await service.download(remotePath: item.path, toLocalURL: url)
            }
        }
    }

    private func batchDownloadWithPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Destination"
        panel.message = "Choose a folder to download \(selection.count) items into"
        if panel.runModal() == .OK, let destDir = panel.url {
            let paths = Array(selection)
            for path in paths {
                let name = (path as NSString).lastPathComponent
                Task {
                    try? await service.download(
                        remotePath: path,
                        toLocalURL: destDir.appendingPathComponent(name)
                    )
                }
            }
        }
    }

    // MARK: - Formatting helpers

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "java", "rb", "sh":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "ico":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar":
            return "archivebox"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "mp3", "aac", "flac", "wav":
            return "music.note"
        default:
            return "doc"
        }
    }
}
