import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Import Wizard Sheet

/// Multi-step import wizard for .mxtsessions files.
/// Triggered by File menu "Import Sessions..." or by dropping a .mxtsessions file onto the sidebar.
struct ImportWizardSheet: View {
    /// Pre-loaded file URL (e.g., from drag-drop). If nil, Step 1 shows a file picker.
    var preloadedURL: URL? = nil

    @Environment(SessionLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var step: ImportStep = .fileSelection
    @State private var parseResult: MXTParseResult? = nil
    @State private var selectedIds: Set<UUID> = []
    @State private var showConflictSheet = false
    @State private var showSummarySheet = false
    @State private var conflictResolutions: [UUID: ConflictResolution] = [:]
    @State private var importStats = ImportStats()
    @State private var parseError: String? = nil

    enum ImportStep { case fileSelection, treePreview }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Import Sessions", systemImage: "square.and.arrow.down")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            switch step {
            case .fileSelection:
                fileSelectionView
            case .treePreview:
                if let result = parseResult {
                    treePreviewView(result: result)
                }
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 520, height: 560)
        .sheet(isPresented: $showConflictSheet) {
            if let result = parseResult {
                let selectedSessions = result.sessions
                    .filter { selectedIds.contains($0.session.id) }
                    .map(\.session)
                let conflicts = SessionConflictResolver().findConflicts(
                    incoming: selectedSessions,
                    existing: library.sessions
                )
                ImportConflictSheet(
                    conflicts: conflicts,
                    resolutions: $conflictResolutions
                ) {
                    showConflictSheet = false
                    commitImport(result: result)
                }
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            ImportSummarySheet(stats: importStats) {
                showSummarySheet = false
                dismiss()
            }
        }
        .onAppear {
            if let url = preloadedURL {
                loadFile(url: url)
            }
        }
    }

    // MARK: - Step 1: File Selection

    private var fileSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a .mxtsessions file to import")
                .font(.title3)
                .foregroundStyle(.secondary)
            if let error = parseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Choose File...") {
                openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 2: Tree Preview

    private func treePreviewView(result: MXTParseResult) -> some View {
        VStack(spacing: 0) {
            // Selection controls
            HStack {
                Button("Select All") {
                    selectedIds = Set(result.sessions.map(\.session.id))
                }
                Button("Deselect All") {
                    selectedIds = []
                }
                Spacer()
                Text("\(selectedIds.count) of \(result.sessions.count) sessions selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tree list
            List {
                // Root-level sessions
                let rootSessions = result.sessions.filter { $0.folderId == nil }
                if !rootSessions.isEmpty {
                    Section(header: Text("(Root)").foregroundStyle(.secondary)) {
                        ForEach(rootSessions, id: \.session.id) { item in
                            ImportSessionRow(session: item.session, selectedIds: $selectedIds)
                        }
                    }
                }

                // Root-level folders (parentId == nil)
                let rootFolders = result.folders.filter { $0.parentId == nil }
                    .sorted { $0.sortOrder < $1.sortOrder }
                ForEach(rootFolders) { folder in
                    ImportFolderSection(folder: folder, result: result, selectedIds: $selectedIds)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            if step == .treePreview {
                Button("Import") { startImport() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIds.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Import Sessions"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "mxtsessions") ?? .data]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            loadFile(url: url)
        }
    }

    private func loadFile(url: URL) {
        parseError = nil
        do {
            let data = try Data(contentsOf: url)
            let parser = MXTSessionsParser()
            let result = try parser.parse(data: data)
            parseResult = result
            // Pre-select all sessions
            selectedIds = Set(result.sessions.map(\.session.id))
            step = .treePreview
        } catch {
            parseError = "Failed to parse file: \(error.localizedDescription)"
        }
    }

    private func startImport() {
        guard let result = parseResult else { return }
        let selectedSessions = result.sessions
            .filter { selectedIds.contains($0.session.id) }
            .map(\.session)
        let conflicts = SessionConflictResolver().findConflicts(
            incoming: selectedSessions,
            existing: library.sessions
        )
        if conflicts.isEmpty {
            // No conflicts — commit immediately
            commitImport(result: result)
        } else {
            // Initialize default resolutions
            for conflict in conflicts {
                conflictResolutions[conflict.incoming.id] = .overwrite
            }
            showConflictSheet = true
        }
    }

    private func commitImport(result: MXTParseResult) {
        var importedSessions = 0
        var createdFolders = 0
        var skippedSessions = 0

        // Build a map from old folder IDs (from parse result) to new folder IDs (in library)
        var folderIdMap: [UUID: UUID] = [:]

        // Add folders in order (parents first — sorted folders by depth)
        let sortedFolders = result.folders.sorted { a, b in
            depth(of: a.id, in: result.folders) < depth(of: b.id, in: result.folders)
        }

        for folder in sortedFolders {
            let newParentId = folder.parentId.flatMap { folderIdMap[$0] }
            let sortOrder = library.folders.filter { $0.parentId == newParentId }.count
            let newFolder = SessionFolder(
                name: folder.name,
                parentId: newParentId,
                sortOrder: sortOrder
            )
            library.addFolder(newFolder)
            folderIdMap[folder.id] = newFolder.id
            createdFolders += 1
        }

        // Add sessions
        let resolver = SessionConflictResolver()
        let existingNamesAtRoot = library.sessions(inFolder: nil).map(\.name)

        for item in result.sessions where selectedIds.contains(item.session.id) {
            let resolution = conflictResolutions[item.session.id] ?? .overwrite
            let newFolderId = item.folderId.flatMap { folderIdMap[$0] }

            // Check if conflict exists
            let conflictExists = library.sessions.contains {
                $0.name.lowercased() == item.session.name.lowercased()
                    && $0.folderId == newFolderId
            }

            if conflictExists {
                switch resolution {
                case .skip:
                    skippedSessions += 1
                    continue
                case .rename:
                    let existingNames = library.sessions(inFolder: newFolderId).map(\.name)
                    var renamed = item.session
                    renamed.folderId = newFolderId
                    renamed = resolver.rename(renamed, avoiding: existingNames)
                    let sortOrder = library.sessions(inFolder: newFolderId).count
                    renamed.folderId = newFolderId
                    let finalSession = SessionDefinition(
                        name: renamed.name,
                        folderId: newFolderId,
                        protocolConfig: item.session.protocolConfig,
                        notes: item.session.notes,
                        sortOrder: sortOrder
                    )
                    library.addSession(finalSession)
                    importedSessions += 1
                case .overwrite:
                    // Delete existing and add new
                    if let existing = library.sessions.first(where: {
                        $0.name.lowercased() == item.session.name.lowercased() && $0.folderId == newFolderId
                    }) {
                        library.deleteSession(id: existing.id)
                    }
                    let sortOrder = library.sessions(inFolder: newFolderId).count
                    let newSession = SessionDefinition(
                        name: item.session.name,
                        folderId: newFolderId,
                        protocolConfig: item.session.protocolConfig,
                        notes: item.session.notes,
                        sortOrder: sortOrder
                    )
                    library.addSession(newSession)
                    importedSessions += 1
                }
            } else {
                let sortOrder = library.sessions(inFolder: newFolderId).count
                let newSession = SessionDefinition(
                    name: item.session.name,
                    folderId: newFolderId,
                    protocolConfig: item.session.protocolConfig,
                    notes: item.session.notes,
                    sortOrder: sortOrder
                )
                library.addSession(newSession)
                importedSessions += 1
            }
        }

        importStats = ImportStats(
            sessionsImported: importedSessions,
            foldersCreated: createdFolders,
            sessionsSkipped: skippedSessions
        )
        showSummarySheet = true
    }

    private func depth(of folderId: UUID, in folders: [SessionFolder]) -> Int {
        guard let folder = folders.first(where: { $0.id == folderId }),
              let parentId = folder.parentId else { return 0 }
        return 1 + depth(of: parentId, in: folders)
    }
}

// MARK: - Import Stats

struct ImportStats {
    var sessionsImported: Int = 0
    var foldersCreated: Int = 0
    var sessionsSkipped: Int = 0
}

// MARK: - Session Row

private struct ImportSessionRow: View {
    let session: SessionDefinition
    @Binding var selectedIds: Set<UUID>

    private var isSelected: Bool { selectedIds.contains(session.id) }

    private var icon: String {
        switch session.protocolConfig {
        case .ssh: return "terminal"
        case .rdp: return "desktopcomputer"
        case .vnc: return "eye"
        }
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isSelected },
            set: { on in
                if on { selectedIds.insert(session.id) }
                else  { selectedIds.remove(session.id) }
            }
        )) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16)
                Text(session.name)
                Spacer()
                Text(session.protocolConfig.hostname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Folder Section (recursive)

private struct ImportFolderSection: View {
    let folder: SessionFolder
    let result: MXTParseResult
    @Binding var selectedIds: Set<UUID>

    private var folderSessions: [SessionDefinition] {
        result.sessions.filter { $0.folderId == folder.id }.map(\.session)
    }

    private var subFolders: [SessionFolder] {
        result.folders.filter { $0.parentId == folder.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allDescendantIds: Set<UUID> {
        var ids = Set(folderSessions.map(\.id))
        for sub in subFolders {
            ids.formUnion(descendantIds(of: sub.id))
        }
        return ids
    }

    private func descendantIds(of folderId: UUID) -> Set<UUID> {
        let sessions = result.sessions.filter { $0.folderId == folderId }.map(\.session.id)
        let subs = result.folders.filter { $0.parentId == folderId }
        return Set(sessions).union(subs.flatMap { descendantIds(of: $0.id) })
    }

    private var allSelected: Bool {
        !allDescendantIds.isEmpty && allDescendantIds.isSubset(of: selectedIds)
    }

    var body: some View {
        Section {
            ForEach(folderSessions) { session in
                ImportSessionRow(session: session, selectedIds: $selectedIds)
            }
            ForEach(subFolders) { subfolder in
                ImportFolderSection(folder: subfolder, result: result, selectedIds: $selectedIds)
            }
        } header: {
            Toggle(isOn: Binding(
                get: { allSelected },
                set: { on in
                    if on { selectedIds.formUnion(allDescendantIds) }
                    else  { selectedIds.subtract(allDescendantIds) }
                }
            )) {
                Label(folder.name, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
        }
    }
}
