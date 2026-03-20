import SwiftUI

@main
struct MobaAltApp: App {
    @State private var library = SessionLibrary()
    private let store = SessionStore()

    init() {
        // Wire up the library to the store: load on init, save on every mutation.
        // We use Task to perform async work at startup.
        Task { @MainActor in
            do {
                let (sessions, folders) = try await store.load()
                library.sessions = sessions
                library.folders = folders
            } catch {
                // On load failure, start with empty library (non-fatal)
                print("[MobaAlt] Failed to load sessions: \(error)")
            }
            library.onMutation = { [library] in
                do {
                    try await store.save(sessions: library.sessions, folders: library.folders)
                } catch {
                    print("[MobaAlt] Failed to save sessions: \(error)")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
        .defaultSize(width: 1100, height: 720)

        Settings {
            PreferencesView()
        }
    }
}
