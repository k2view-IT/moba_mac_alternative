# Architecture Patterns

**Domain:** Native macOS Remote Session Manager (SSH/RDP/VNC)
**Researched:** 2026-03-19
**Confidence:** MEDIUM (based on training data; web search unavailable for verification)

## Recommended Architecture

### High-Level Overview

```
+------------------------------------------------------------------+
|                        App Shell (SwiftUI)                        |
|  +------------+  +-------------------------------------------+   |
|  |  Sidebar   |  |           Tab Container                   |   |
|  |            |  |  +------+ +------+ +------+ +------+      |   |
|  | Session    |  |  | Tab1 | | Tab2 | | Tab3 | | Tab4 |      |   |
|  | Browser    |  |  +------+ +------+ +------+ +------+      |   |
|  |            |  |  +-------------------------------------+  |   |
|  | - Folders  |  |  |  Active Tab Content                 |  |   |
|  | - Sessions |  |  |                                     |  |   |
|  | - Search   |  |  |  SSH: SwiftTerm + SFTP Panel        |  |   |
|  |            |  |  |  RDP: Status/Launch View             |  |   |
|  +------------+  |  |  VNC: Status/Launch View             |  |   |
|                  |  +-------------------------------------+  |   |
|                  +-------------------------------------------+   |
+------------------------------------------------------------------+
         |                    |                    |
   SessionStore         ConnectionManager    CredentialStore
   (Persistence)        (Process Lifecycle)  (Keychain + Vault)
```

### App Architecture Pattern: MVVM with Service Layer

**Use MVVM with `@Observable` (Swift 5.9+), not TCA.**

Rationale:
- TCA (The Composable Architecture) adds significant complexity and learning curve for a team tool. Overkill for this scope.
- Plain `@Observable` macro (Observation framework) is the modern replacement for ObservableObject. Simpler, better performance, no manual `@Published` needed.
- MVVM keeps views thin, ViewModels testable, and Services reusable.
- The app is not deeply composable (no recursive UI trees) -- it is a session manager with a handful of distinct screen types.

```
View Layer (SwiftUI)
    |
ViewModel Layer (@Observable classes)
    |
Service Layer (protocols + implementations)
    |
Data Layer (persistence, Keychain, filesystem)
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **AppShell** | Window management, NavigationSplitView, menu bar | TabManager, SessionBrowser |
| **SessionBrowser** | Sidebar: folder tree, session list, search/filter | SessionStore, TabManager |
| **TabManager** | Open/close/switch tabs, tab state, active tab tracking | ConnectionManager, individual tab ViewModels |
| **SSHTabView** | Terminal display (SwiftTerm) + optional SFTP panel | SSHConnection, SFTPService |
| **RDPTabView** | Connection status, launch button, session info | RDPLauncher |
| **VNCTabView** | Connection status, launch button, session info | VNCLauncher |
| **SessionStore** | CRUD for saved sessions + folder hierarchy, persistence | JSON/SQLite on disk |
| **ConnectionManager** | Lifecycle management for all active connections | SSHConnection, RDPLauncher, VNCLauncher |
| **CredentialStore** | Password retrieval/storage, SSH key management | macOS Keychain, encrypted vault file |
| **XQuartzDetector** | Detect XQuartz install, DISPLAY env setup, install guidance | System environment, NSWorkspace |

## Data Flow

### Session Creation and Connection Flow

```
User creates session in SessionBrowser
    |
    v
SessionStore.save(session)  -->  Persists to disk (JSON or SQLite)
    |
    v
User double-clicks session to connect
    |
    v
TabManager.openTab(for: session)
    |
    v
ConnectionManager.connect(session)
    |
    +-- SSH: SSHConnection spawns Process(/usr/bin/ssh)
    |         |
    |         +-- stdout/stdin piped to SwiftTerm via TerminalDelegate
    |         +-- SFTPService spawns sftp subprocess or uses libssh2
    |
    +-- RDP: RDPLauncher opens rdp:// URL via NSWorkspace
    |         or launches "Microsoft Remote Desktop" with .rdp file
    |
    +-- VNC: VNCLauncher opens vnc:// URL via NSWorkspace
              (invokes macOS built-in Screen Sharing.app)
```

### Data Model Flow

```
SessionDefinition (saved config)
    |
    v
ConnectionState (runtime state: connecting/connected/disconnected/error)
    |
    v
TabState (UI state: which tab is active, tab ordering)
```

### Credential Flow

```
Session needs auth
    |
    v
CredentialStore.retrieve(for: session)
    |
    +-- Password auth: Keychain.lookup(service, account)
    |
    +-- Key auth: EncryptedVault.decryptKey(keyId, passphrase)
    |
    v
Credential passed to SSHConnection (never stored in memory longer than needed)
```

## Core Data Models

```swift
// Protocol-agnostic session definition
enum ConnectionProtocol {
    case ssh(SSHConfig)
    case rdp(RDPConfig)
    case vnc(VNCConfig)
}

struct SessionDefinition: Identifiable, Codable {
    let id: UUID
    var name: String
    var folderId: UUID?       // nil = root level
    var protocolConfig: ConnectionProtocol
    var credentialRef: CredentialReference?  // pointer, not the credential itself
    var tags: [String]
    var lastConnected: Date?
    var createdAt: Date
}

struct SSHConfig: Codable {
    var hostname: String
    var port: Int              // default 22
    var username: String
    var authMethod: SSHAuthMethod
    var x11Forwarding: Bool
    var jumpHost: SessionDefinition.ID?  // optional proxy jump
}

struct RDPConfig: Codable {
    var hostname: String
    var port: Int              // default 3389
    var username: String?
    var domain: String?
    var screenResolution: RDPResolution?
}

struct VNCConfig: Codable {
    var hostname: String
    var port: Int              // default 5900
    var viewOnly: Bool
}

enum SSHAuthMethod: Codable {
    case password
    case privateKey(keyId: UUID)
    case agent                 // ssh-agent forwarding
}

struct CredentialReference: Codable {
    let id: UUID
    var label: String
    var storageType: CredentialStorageType
}

enum CredentialStorageType: Codable {
    case keychain              // password in macOS Keychain
    case encryptedVault        // SSH key in AES-encrypted file
}

// Folder hierarchy
struct SessionFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var parentId: UUID?        // nil = root
    var sortOrder: Int
}
```

## Patterns to Follow

### Pattern 1: Protocol-Polymorphic Tabs via Enum Dispatch

**What:** Model each tab as a wrapper around a protocol-specific ViewModel, dispatched via a single enum.
**When:** Always -- this is the core tab architecture.
**Why:** Avoids separate tab management logic per protocol. Single TabManager handles all types.

```swift
@Observable
class TabManager {
    var tabs: [TabItem] = []
    var activeTabId: UUID?

    func openTab(for session: SessionDefinition) {
        let tab = TabItem(session: session)
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.last?.id
        }
    }
}

struct TabItem: Identifiable {
    let id = UUID()
    let session: SessionDefinition
    var connectionState: ConnectionState = .disconnected
}

// In the view layer, dispatch on protocol:
struct TabContentView: View {
    let tab: TabItem

    var body: some View {
        switch tab.session.protocolConfig {
        case .ssh:   SSHTabView(tab: tab)
        case .rdp:   RDPTabView(tab: tab)
        case .vnc:   VNCTabView(tab: tab)
        }
    }
}
```

### Pattern 2: SwiftTerm Integration via NSViewRepresentable

**What:** Wrap SwiftTerm's `TerminalView` (AppKit NSView) in a SwiftUI `NSViewRepresentable`.
**When:** For all SSH terminal tabs.
**Why:** SwiftTerm is an AppKit library. SwiftUI has no native terminal view. NSViewRepresentable is the standard bridging pattern.

```swift
struct TerminalViewWrapper: NSViewRepresentable {
    let connection: SSHConnection

    func makeNSView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.delegate = context.coordinator
        connection.attachTerminal(terminalView)
        return terminalView
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        // Typically no-op; terminal handles its own updates
    }

    func makeCoordinator() -> TerminalCoordinator {
        TerminalCoordinator(connection: connection)
    }
}
```

### Pattern 3: SSH Process Management via Foundation.Process

**What:** Spawn `/usr/bin/ssh` as a child process, pipe stdin/stdout/stderr to SwiftTerm.
**When:** For all SSH connections.
**Why:** Using the system SSH client means: no need to bundle libssh2, automatic support for ~/.ssh/config, agent forwarding works out of the box, ProxyJump works, known_hosts is respected. This is how iTerm2 and Terminal.app work.

```swift
@Observable
class SSHConnection {
    private var process: Process?
    private var inputPipe = Pipe()
    private var outputPipe = Pipe()

    func connect(config: SSHConfig, credential: Credential?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = buildArgs(from: config)
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe  // merge stderr into terminal

        if config.x11Forwarding {
            var env = ProcessInfo.processInfo.environment
            env["DISPLAY"] = detectDisplay()  // typically ":0" or "localhost:0"
            process.environment = env
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            // Forward to SwiftTerm on main thread
            DispatchQueue.main.async {
                self?.terminalView?.feed(byteArray: [UInt8](data))
            }
        }

        try? process.run()
        self.process = process
    }

    func send(_ data: Data) {
        inputPipe.fileHandleForWriting.write(data)
    }
}
```

### Pattern 4: SFTP as a Split-View Companion

**What:** SFTP panel sits alongside the terminal in SSH tabs, sharing the same connection context.
**When:** SSH tabs only. Toggle-able by user.
**Why:** MobaXterm's signature UX -- terminal on right, file browser on left.

```swift
struct SSHTabView: View {
    @State var showSFTP = true
    let tab: TabItem

    var body: some View {
        HSplitView {
            if showSFTP {
                SFTPPanelView(hostname: tab.session.hostname,
                              credential: tab.session.credentialRef)
                    .frame(minWidth: 200, idealWidth: 280)
            }
            TerminalViewWrapper(connection: sshConnection)
        }
        .toolbar {
            Toggle("SFTP", isOn: $showSFTP)
        }
    }
}
```

SFTP implementation: Spawn a separate `sftp` subprocess or use NMSSH/libssh2 Swift wrapper. Subprocess approach (`/usr/bin/sftp -b`) is simpler but harder to parse; libssh2 wrapper gives programmatic file listing. Recommend starting with a subprocess for v1 simplicity, upgrading to libssh2 if needed.

### Pattern 5: RDP/VNC as External Launchers

**What:** RDP and VNC tabs show connection status and a "Connect" button. Actual protocol handling is delegated to system apps via URL schemes.
**When:** All RDP and VNC connections.
**Why:** Implementing RDP/VNC from scratch is a multi-year effort. macOS has built-in VNC (Screen Sharing) and Microsoft Remote Desktop is free. Delegating is pragmatic.

```swift
struct RDPLauncher {
    func launch(config: RDPConfig) {
        // Option A: URL scheme (if Microsoft Remote Desktop is installed)
        if let url = URL(string: "rdp://full%20address=s:\(config.hostname):\(config.port)") {
            NSWorkspace.shared.open(url)
        }

        // Option B: Generate .rdp file, open with default handler
        // let rdpFile = generateRDPFile(config)
        // NSWorkspace.shared.open(rdpFile)
    }
}

struct VNCLauncher {
    func launch(config: VNCConfig) {
        // macOS built-in Screen Sharing handles vnc:// URLs
        if let url = URL(string: "vnc://\(config.hostname):\(config.port)") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### Pattern 6: Session Persistence with JSON Files (v1)

**What:** Store sessions and folders as JSON files on disk. One file per data type.
**When:** v1 -- simple, inspectable, no dependencies.
**Why:** SQLite is overkill for hundreds-to-low-thousands of sessions. JSON is debuggable, diffable, and trivially implementable. Migrate to SQLite only if performance requires it.

```swift
actor SessionStore {
    private let sessionsURL: URL  // ~/Library/Application Support/MobaAlt/sessions.json
    private let foldersURL: URL   // ~/Library/Application Support/MobaAlt/folders.json

    func loadSessions() async throws -> [SessionDefinition] { ... }
    func save(_ session: SessionDefinition) async throws { ... }
    func delete(_ id: UUID) async throws { ... }
    func loadFolders() async throws -> [SessionFolder] { ... }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Embedding RDP/VNC Protocol Implementations

**What:** Attempting to implement RDP or VNC protocol handling in Swift.
**Why bad:** Enormous scope. FreeRDP alone is 500K+ lines of C. Screen rendering, input handling, clipboard sync, audio forwarding -- each is a project in itself. This would turn a session manager into a multi-year protocol engineering project.
**Instead:** Delegate to system apps. Keep the app focused on session organization and SSH terminal.

### Anti-Pattern 2: Single Monolithic ViewModel

**What:** One giant ViewModel that manages sessions, tabs, connections, credentials, and SFTP.
**Why bad:** Untestable, unmaintainable, impossible to reason about state.
**Instead:** Separate ViewModels per concern: `SessionBrowserViewModel`, `TabManager`, `SSHTabViewModel`, `SFTPViewModel`. Share state through injected services.

### Anti-Pattern 3: Storing Credentials in SessionDefinition

**What:** Embedding passwords or key material directly in session config objects.
**Why bad:** Credentials end up in JSON on disk, in memory dumps, in debug logs. Security violation.
**Instead:** Store only a `CredentialReference` (UUID + type) in sessions. Actual secrets live in Keychain or encrypted vault, retrieved on demand.

### Anti-Pattern 4: Using SwiftUI for Terminal Rendering

**What:** Trying to build a terminal emulator purely in SwiftUI (Text views, custom rendering).
**Why bad:** Terminal emulation requires precise character-cell rendering, escape sequence handling, scrollback buffers, selection, and sub-frame update performance. SwiftUI's layout engine is not designed for this.
**Instead:** Use SwiftTerm (AppKit NSView) wrapped in NSViewRepresentable. Let AppKit handle the performance-critical rendering.

### Anti-Pattern 5: Synchronous File I/O on Main Thread

**What:** Loading sessions, reading SFTP directory listings, or accessing Keychain on the main thread.
**Why bad:** Blocks the UI. SFTP directory listings over slow connections can take seconds.
**Instead:** All I/O through `async/await`. Use Swift actors for thread-safe state. Keep the main thread exclusively for UI.

## Detailed Component Design

### Credential Store Layer

```
CredentialStore (protocol)
    |
    +-- KeychainProvider: passwords via Security framework
    |       - SecItemAdd / SecItemCopyMatching / SecItemUpdate / SecItemDelete
    |       - Service name: "com.mobaalt.sessions"
    |       - Account: session UUID string
    |
    +-- EncryptedVaultProvider: SSH private keys
            - AES-256-GCM encryption
            - Master password derived via PBKDF2 (or Argon2 via CryptoKit)
            - Vault file: ~/Library/Application Support/MobaAlt/keyvault.enc
            - Keys indexed by UUID, stored as encrypted blobs
            - Vault unlocked once per app session (master key in memory)
```

### XQuartz Detection

```swift
struct XQuartzDetector {
    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/opt/X11/bin/xquartz")
            || FileManager.default.fileExists(atPath: "/Applications/Utilities/XQuartz.app")
    }

    func displayVariable() -> String? {
        guard isInstalled() else { return nil }
        // XQuartz typically sets DISPLAY to /tmp/.X11-unix/X0
        // or :0 when running
        return ProcessInfo.processInfo.environment["DISPLAY"] ?? ":0"
    }

    func installURL() -> URL {
        URL(string: "https://www.xquartz.org/")!
    }
}
```

### Tab Management Architecture

The tab system is the most complex UI component. Key considerations:

1. **Tab identity**: Each tab has a UUID, not tied to session ID (user can open multiple tabs to the same server).
2. **Tab lifecycle**: Open -> Connecting -> Connected -> Disconnected (with reconnect option).
3. **Tab persistence across app restart**: Optional. Store open tab IDs in UserDefaults; reconnect on launch.
4. **Tab drag reordering**: Use SwiftUI's `onMove` or a custom drag-and-drop implementation.
5. **Memory management**: Disconnected tabs should release Process handles and pipe buffers. Terminal scrollback can be capped.

```swift
@Observable
class TabManager {
    var tabs: [TabItem] = []
    var activeTabId: UUID?

    // Tab operations
    func openTab(for session: SessionDefinition) -> TabItem
    func closeTab(_ id: UUID)
    func closeAllTabs()
    func activateTab(_ id: UUID)
    func moveTab(from: IndexSet, to: Int)

    // Bulk operations
    func disconnectAll()
    func reconnectTab(_ id: UUID)
}
```

## Suggested Build Order

Build order follows dependency chains. Each phase produces a usable increment.

```
Phase 1: Foundation
    SessionDefinition model + SessionStore (JSON persistence)
    SessionFolder model + folder CRUD
    App shell with NavigationSplitView (sidebar + detail)
    SessionBrowser sidebar (list sessions, create/edit/delete)
    --> Deliverable: App that can create, organize, and persist sessions (no connections)

Phase 2: SSH Core
    SSHConnection (Process spawning, pipe management)
    SwiftTerm integration (NSViewRepresentable wrapper)
    TabManager + tab bar UI
    Connect a saved SSH session -> opens terminal in tab
    --> Deliverable: Working SSH terminal with tabbed sessions

Phase 3: Credentials
    CredentialStore protocol + KeychainProvider (passwords)
    EncryptedVaultProvider (SSH keys)
    Auth method selection in session editor
    SSH connection uses stored credentials
    --> Deliverable: Secure credential management for SSH

Phase 4: SFTP
    SFTPService (subprocess or libssh2)
    SFTPPanelView (file listing, upload, download)
    HSplitView integration in SSHTabView
    --> Deliverable: MobaXterm-style terminal + file browser

Phase 5: RDP/VNC + X11
    RDPLauncher + RDPTabView (status + launch)
    VNCLauncher + VNCTabView (status + launch)
    XQuartzDetector + X11 forwarding toggle
    XQuartz install guide UI
    --> Deliverable: Full multi-protocol session manager

Phase 6: Polish + Distribution
    Session search/filter
    Tab drag reordering
    Keyboard shortcuts
    DMG packaging (create-dmg or Packages.app)
    --> Deliverable: Distributable DMG
```

**Dependency chain rationale:**
- Phase 1 must come first: every other component depends on SessionDefinition and SessionStore.
- Phase 2 before Phase 3: get SSH working with manual password entry first, then layer credentials on top. This validates the terminal and process management before adding complexity.
- Phase 3 before Phase 4: SFTP needs credentials too; sharing the credential layer avoids duplication.
- Phase 4 before Phase 5: SFTP is the core differentiator (MobaXterm's signature feature). RDP/VNC are simpler (URL scheme launchers) and can come later.
- Phase 5 before Phase 6: all features must exist before polish and distribution.

## Scalability Considerations

| Concern | At 50 sessions | At 500 sessions | At 5000 sessions |
|---------|----------------|-----------------|-------------------|
| Session loading | JSON loads instantly (<1ms) | JSON fine (<10ms) | Consider SQLite + lazy loading |
| Open tabs | 5-10 tabs typical | 20+ tabs: cap scrollback to 10K lines | Memory pressure: disconnect idle tabs |
| Sidebar rendering | Flat list OK | Need folder collapsing, lazy rendering | Virtual list (LazyVStack) essential |
| Credential lookup | Keychain fast | Keychain fast | Keychain fast (indexed by service+account) |

For v1, target: up to 500 sessions, up to 20 concurrent tabs. This covers the stated use case (IT team sharing a session manager).

## Technology Decisions for Architecture

| Decision | Choice | Confidence | Rationale |
|----------|--------|------------|-----------|
| App architecture pattern | MVVM + @Observable | HIGH | Standard macOS SwiftUI pattern, no external dependencies |
| Terminal emulator | SwiftTerm via NSViewRepresentable | HIGH | Only mature Swift terminal library; used by multiple shipping apps |
| SSH implementation | System /usr/bin/ssh via Process | HIGH | Inherits user's SSH config, agent, known_hosts. Zero protocol code. |
| SFTP implementation | Subprocess (/usr/bin/sftp) for v1 | MEDIUM | Simple to start; may need libssh2 for better UX later |
| Session persistence | JSON files in Application Support | HIGH | Sufficient for v1 scale, zero dependencies |
| Credential storage | Keychain (passwords) + AES-GCM vault (keys) | HIGH | macOS best practice for passwords; vault needed for key material |
| RDP/VNC | NSWorkspace URL scheme launchers | HIGH | Correct pragmatic choice per project constraints |
| Window management | Single-window, NavigationSplitView | HIGH | MobaXterm model; standard macOS pattern |

## Sources

- SwiftTerm GitHub repository (migueldeicaza/SwiftTerm) -- training data, MEDIUM confidence
- Apple Developer Documentation: NSViewRepresentable, @Observable, NavigationSplitView -- training data, HIGH confidence
- Apple Developer Documentation: Security framework (Keychain Services) -- training data, HIGH confidence
- macOS URL scheme handling for VNC (vnc://) and RDP (rdp://) -- training data, MEDIUM confidence
- Foundation.Process documentation -- training data, HIGH confidence

**Note:** Web search was unavailable during this research session. All findings are based on training data (cutoff May 2025). SwiftTerm API specifics and any changes to macOS URL scheme handling after that date should be verified during implementation.
