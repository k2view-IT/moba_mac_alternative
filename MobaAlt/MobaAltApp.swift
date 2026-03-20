import SwiftUI

@main
struct MobaAltApp: App {
    @State private var library = SessionLibrary()
    private let store = SessionStore()

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
        }
        .defaultSize(width: 1100, height: 720)

        Settings {
            PreferencesView()
        }
    }
}
