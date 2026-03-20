import SwiftUI

@main
struct MobaAltApp: App {
    @State private var library = SessionLibrary()
    private let store = SessionStore()

    // Import/Export sheet state (driven by menu commands)
    @State private var showingImportFromMenu = false
    @State private var showingExportFromMenu = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .task {
                    // Wire save-on-mutation before loading so no writes are missed.
                    library.onMutation = { [library, store] in
                        do {
                            try await store.save(sessions: library.sessions, folders: library.folders)
                        } catch {
                            print("[MobaAlt] Failed to save sessions: \(error)")
                        }
                    }
                    // Load persisted sessions; failures are non-fatal.
                    do {
                        let (sessions, folders) = try await store.load()
                        library.sessions = sessions
                        library.folders = folders
                    } catch {
                        print("[MobaAlt] Failed to load sessions: \(error)")
                    }
                }
                .sheet(isPresented: $showingImportFromMenu) {
                    ImportWizardSheet(preloadedURL: nil)
                        .environment(library)
                }
                .sheet(isPresented: $showingExportFromMenu) {
                    ExportDialogSheet(initialFolderId: nil)
                        .environment(library)
                }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Divider()
                Button("Import Sessions…") {
                    showingImportFromMenu = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export Sessions…") {
                    showingExportFromMenu = true
                }
            }
        }

        Settings {
            PreferencesView()
        }
    }
}
