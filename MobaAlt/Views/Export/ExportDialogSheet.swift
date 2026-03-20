import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case json       = "JSON (.json)"
    case mxtsessions = "MobaXterm (.mxtsessions)"
    case html       = "HTML Report (.html)"
    var id: String { rawValue }
}

// MARK: - ExportDialogSheet

/// Single export entry point: checkbox tree of folders/sessions + format picker → NSSavePanel.
/// Pass `initialFolderId` to pre-select a specific folder; leave nil to select everything.
struct ExportDialogSheet: View {
    var initialFolderId: UUID? = nil

    @Environment(SessionLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSessionIds: Set<UUID> = []
    @State private var exportFormat: ExportFormat = .json

    private var allSessionIds: Set<UUID> { Set(library.sessions.map(\.id)) }

    private var selectedSessions: [SessionDefinition] {
        library.sessions.filter { selectedSessionIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack {
                Label("Export Sessions", systemImage: "square.and.arrow.up")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.bar)

            Divider()

            // ── Format picker ─────────────────────────────────────────
            HStack(spacing: 12) {
                Text("Format:")
                    .foregroundStyle(.secondary)
                Picker("", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // ── Selection controls ────────────────────────────────────
            HStack {
                Button("Select All") { selectedSessionIds = allSessionIds }
                Button("None")       { selectedSessionIds = [] }
                Spacer()
                Text("\(selectedSessionIds.count) / \(library.sessions.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // ── Tree ──────────────────────────────────────────────────
            List {
                // Root-level sessions
                let rootSessions = library.sessions(inFolder: nil)
                if !rootSessions.isEmpty {
                    Section {
                        ForEach(rootSessions) { session in
                            ExportSessionRow(session: session, selectedIds: $selectedSessionIds)
                        }
                    } header: {
                        Text("(Root)").foregroundStyle(.secondary)
                    }
                }
                // Root-level folders (recursive)
                ForEach(library.subfolders(of: nil)) { folder in
                    ExportFolderSection(folder: folder, selectedIds: $selectedSessionIds)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            // ── Footer ────────────────────────────────────────────────
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export…") { runExport() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSessionIds.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 540)
        .onAppear { initSelection() }
    }

    // MARK: - Helpers

    private func initSelection() {
        if let folderId = initialFolderId {
            selectedSessionIds = allDescendantIds(of: folderId)
        } else {
            selectedSessionIds = allSessionIds
        }
    }

    private func allDescendantIds(of folderId: UUID) -> Set<UUID> {
        var ids = Set(library.sessions(inFolder: folderId).map(\.id))
        for sub in library.subfolders(of: folderId) {
            ids.formUnion(allDescendantIds(of: sub.id))
        }
        return ids
    }

    private func runExport() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        switch exportFormat {
        case .json:
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "sessions.json"
        case .mxtsessions:
            panel.allowedContentTypes = [UTType(filenameExtension: "mxtsessions") ?? .data]
            panel.nameFieldStringValue = "sessions.mxtsessions"
        case .html:
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = "sessions.html"
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            // Actual file writing wired in plan 01-03
            print("[Export] \(selectedSessions.count) sessions → \(url.path) as \(exportFormat.rawValue)")
            dismiss()
        }
    }
}

// MARK: - Session row

private struct ExportSessionRow: View {
    let session: SessionDefinition
    @Binding var selectedIds: Set<UUID>

    private var isOn: Bool { selectedIds.contains(session.id) }

    private var icon: String {
        switch session.protocolConfig {
        case .ssh: return "terminal"
        case .rdp: return "desktopcomputer"
        case .vnc: return "eye"
        }
    }

    private var color: Color {
        switch session.protocolConfig {
        case .ssh: return .green
        case .rdp: return .blue
        case .vnc: return .orange
        }
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { on in
                if on { selectedIds.insert(session.id) }
                else  { selectedIds.remove(session.id) }
            }
        )) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).frame(width: 16)
                Text(session.name)
                Spacer()
                Text(session.protocolConfig.hostname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Folder section (recursive)

private struct ExportFolderSection: View {
    let folder: SessionFolder
    @Binding var selectedIds: Set<UUID>

    @Environment(SessionLibrary.self) private var library

    private func allDescendantIds(of folderId: UUID) -> Set<UUID> {
        var ids = Set(library.sessions(inFolder: folderId).map(\.id))
        for sub in library.subfolders(of: folderId) {
            ids.formUnion(allDescendantIds(of: sub.id))
        }
        return ids
    }

    private var descendantIds: Set<UUID> { allDescendantIds(of: folder.id) }

    private var folderAllSelected: Bool {
        !descendantIds.isEmpty && descendantIds.isSubset(of: selectedIds)
    }

    var body: some View {
        let sessions   = library.sessions(inFolder: folder.id)
        let subfolders = library.subfolders(of: folder.id)

        Section {
            if sessions.isEmpty && subfolders.isEmpty {
                Text("Empty folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    ExportSessionRow(session: session, selectedIds: $selectedIds)
                }
                ForEach(subfolders) { subfolder in
                    ExportFolderSection(folder: subfolder, selectedIds: $selectedIds)
                }
            }
        } header: {
            Toggle(isOn: Binding(
                get: { folderAllSelected },
                set: { on in
                    if on { selectedIds.formUnion(descendantIds) }
                    else  { selectedIds.subtract(descendantIds) }
                }
            )) {
                Label(folder.name, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
        }
    }
}
