# Phase 3: SFTP File Browser - Research

**Researched:** 2026-03-22
**Domain:** SFTP file browser panel — macOS Swift/SwiftUI, SSH ControlMaster multiplexing, drag-and-drop, file operations
**Confidence:** MEDIUM-HIGH (key architecture choices verified via official docs + source inspection; libssh2 SPM wrapper landscape verified via web search)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Panel Layout & Position**
- Default position: LEFT — SFTP panel on the left, terminal on the right
- Panel is resizable — draggable divider between SFTP and terminal
- Default width: ~280px
- Position is user-configurable at two levels:
  1. Preferences — sets the global default (Left / Right / Bottom)
  2. Per-tab toolbar button — cycles through Left / Right / Bottom / Hidden for the current session; overrides the global default for that tab

**Panel Trigger & Persistence**
- Auto-opens on every SSH connect — panel appears automatically alongside the terminal
- If user closes the panel, it re-opens automatically on the next SSH connection (not remembered as "closed")
- User must explicitly hide it each session, or change the global default in Preferences

**File Browser Design**
- List view with columns: filename, size, modified date — like Finder list view
- Sortable columns (click header to sort)
- Default sort: folders first, then files A–Z
- Breadcrumb path bar at top — clickable path segments to jump up directories; double-click folders to navigate into them
- Hidden files (dotfiles): hidden by default, toggleable with ⌘Shift+. (same as Finder)

**File Transfer UX**
- Upload: drag files/folders from Finder onto the SFTP panel → uploads to current directory. Also a toolbar "Upload" button that opens a file picker
- Download: drag files from SFTP panel to Finder/Desktop. Also right-click → Download with save dialog
- Double-click a file: downloads to a temp folder and opens in the default macOS app (WinSCP-style)
- Progress display: slim progress bar + filename at the bottom of the SFTP panel. Multiple simultaneous transfers shown as a queue list. No blocking modal.

**File Operations (Context Menu)**
- Core set: New File, New Folder, Rename, Delete, Download, Copy Path
- Inline rename: click to select, press Enter or click again to edit inline — no dialog
- Multi-select: Cmd+click and drag-select for batch download/delete

### Claude's Discretion
- Exact progress bar visual design (color, height, animation)
- How to handle transfer errors (retry logic, error messages)
- Exact ⌘Shift+. keyboard shortcut implementation for hidden files toggle
- Column width defaults and minimum widths
- File type icons (use system NSWorkspace icons vs custom)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SFTP-01 | An SFTP file browser panel opens automatically alongside every SSH terminal session | ContentView split-view refactor + TabItem state extension; panel lifecycle bound to SSHConnection.state |
| SFTP-02 | User can browse the remote directory tree in the SFTP panel | SFTPBrowserService protocol + /usr/bin/sftp subprocess backend; directory listing via `ls -la` commands piped through stdin/stdout |
| SFTP-03 | User can upload files to the remote host via drag-and-drop into the SFTP panel | NSView drop target (NSDraggingDestination) for Finder-to-panel drops + NSOpenPanel for toolbar upload button |
| SFTP-04 | User can download files from the remote host via drag-and-drop or context menu | NSFilePromiseProvider AppKit drag-out for panel-to-Finder + NSSavePanel for right-click download |
| SFTP-05 | User can create, rename, and delete files and folders via the SFTP panel | SFTP subprocess commands: mkdir, rename, rm — issued as batch stdin commands; inline TextField rename in SwiftUI List |
</phase_requirements>

---

## Summary

Phase 3 adds a visual SFTP file browser panel that rides on the ControlMaster socket already established by Phase 2. The core architecture question — libssh2 Swift wrapper vs. `/usr/bin/sftp` subprocess — resolves clearly in favor of the **subprocess approach** given this project's established pattern of using system binaries (system `ssh` for terminals) and the absence of a mature, SPM-native libssh2 wrapper with SFTP support. The `/usr/bin/sftp -b -` subprocess with `-o ControlMaster=no -o ControlPath=<sock>` multiplexes over the existing connection with zero re-authentication and minimal new dependencies.

The split-view layout is straightforward: `ContentView.swift`'s detail area gets wrapped in `HSplitView` (or `VSplitView` for Bottom position) with the SFTP panel as the first child. Panel position and visibility are tracked on `TabItem` (per-tab) and `@AppStorage("sftpDefaultPosition")` (global default). The existing `@Observable @MainActor` service pattern is extended with `SFTPBrowserService` — one instance per tab — owned by `TabManager`.

The one drag-and-drop complexity that requires special attention: **downloading files from the panel to Finder requires AppKit's `NSFilePromiseProvider`** — SwiftUI's `onDrag` modifier does not support file promises and cannot properly hand off files to Finder. This means `SFTPFileRowView` must be an `NSViewRepresentable` wrapper or the drag source must be implemented in an `NSView` subclass. Upload (Finder-to-panel) can use SwiftUI's `onDrop` with `DropDelegate`.

**Primary recommendation:** Use `/usr/bin/sftp -b -` subprocess with ControlMaster socket multiplexing for the SFTP backend, `SFTPBrowserService` as a `@Observable @MainActor` class per tab, `HSplitView`/`VSplitView` for the panel layout, AppKit's `NSFilePromiseProvider` for drag-to-Finder download, and `AsyncThrowingStream<TransferProgress, Error>` for progress reporting.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `/usr/bin/sftp` (system binary) | OpenSSH bundled with macOS 14 | SFTP backend — directory listing, upload, download, file ops | Zero new dependencies; rides ControlMaster socket already present from Phase 2; same process-spawn pattern as SSH terminal sessions |
| Foundation.Process | macOS built-in | Spawn and communicate with sftp subprocess | Already used for SSH terminal; proven pattern in this codebase |
| SwiftUI (HSplitView / VSplitView) | macOS 14+ | Panel layout alongside terminal | Native split view with draggable divider; `idealWidth` sets 280px default |
| AppKit (NSDraggingDestination, NSFilePromiseProvider) | macOS 14+ | Drag-and-drop for upload (from Finder) and download (to Finder) | SwiftUI onDrag cannot produce file promises needed by Finder; must use AppKit |
| AsyncThrowingStream | Swift 5.9+ | Progress reporting for transfers | Pattern confirmed in community resources; integrates cleanly with async/await and SwiftUI observation |
| @AppStorage | macOS 14+ | Persist global SFTP panel position preference | Built-in; consistent with how other prefs are stored in this codebase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| NSWorkspace.shared.open(url:) | macOS built-in | Double-click file: open in default app after temp download | WinSCP-style double-click behaviour |
| NSOpenPanel | macOS built-in | Toolbar "Upload" button — pick local files | Alternative upload path alongside drag-drop |
| NSSavePanel | macOS built-in | Right-click → Download with save dialog | User picks download destination |
| Swift Testing framework (`@Test`, `#expect`) | Swift 5.9+ | Unit tests for SFTPBrowserService, progress model | Already used in this codebase (all Phase 2 tests use Swift Testing) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `/usr/bin/sftp` subprocess | libssh2 SPM wrapper (e.g., Lakr233/libssh2-spm, mplpl/mft) | libssh2-spm is a thin C re-export (LOW confidence for SFTP API coverage); mft uses libssh but is distributed as xcframework (no SPM source), is LGPL-2.1, and requires a separate SSH connection (no ControlMaster reuse). Subprocess approach has zero new dependencies, reuses ControlMaster socket, and is fully consistent with the project's "use system binaries" architecture |
| AppKit NSFilePromiseProvider | SwiftUI Transferable + FileRepresentation | SwiftUI drag-drop does not support file promises; Finder will not accept drops without NSFilePromiseProvider. This is a confirmed SwiftUI limitation as of macOS 14 |
| HSplitView | stevengharris/SplitView (SPM) | Third-party dependency not needed; HSplitView with `frame(idealWidth: 280)` achieves the requirement |

**Installation:** No new dependencies required. All stack components are system frameworks or built-in Swift.

---

## Architecture Patterns

### Recommended Project Structure
```
MobaAlt/
  Models/
    SFTPItem.swift               # Value type: remote file/directory metadata
    TransferTask.swift           # Value type: in-progress transfer state
  Services/
    SFTPBrowserService.swift     # @Observable @MainActor: one per tab, owns sftp subprocess
    SFTPSubprocessChannel.swift  # Internal: writes commands to stdin, reads stdout
  Views/
    SFTP/
      SFTPPanelView.swift        # Top-level panel: breadcrumb + list + progress footer
      SFTPBreadcrumbBar.swift    # Clickable path segments
      SFTPFileListView.swift     # SwiftUI List with sortable columns
      SFTPFileRowView.swift      # Single row: icon, name, size, date; drag source (NSViewRepresentable)
      SFTPTransferFooter.swift   # Progress bar + transfer queue display
      SFTPDropTargetView.swift   # NSViewRepresentable wrapping NSDraggingDestination for upload
  Utilities/
    SFTPPanelPosition.swift      # Enum: left, right, bottom, hidden
```

### Pattern 1: ContentView Split-View Refactor

**What:** Wrap the existing `VStack(spacing:0) { TerminalTabBar; TerminalTabView }` in `HSplitView` with `SFTPPanelView` as the first child (Left position). Switch to `VSplitView` for Bottom, or omit SFTP view for Hidden.

**When to use:** Every SSH session tab; panel position driven by `activeTab.sftpPosition`.

**Example:**
```swift
// ContentView.swift — detail area (replaces current VStack)
// Source: existing ContentView.swift pattern + HSplitView docs

var detailBody: some View {
    switch activeTab.sftpPosition {
    case .left:
        HSplitView {
            SFTPPanelView(service: activeTab.sftpService)
                .frame(minWidth: 180, idealWidth: 280, maxWidth: 500)
            terminalStack
        }
    case .right:
        HSplitView {
            terminalStack
            SFTPPanelView(service: activeTab.sftpService)
                .frame(minWidth: 180, idealWidth: 280, maxWidth: 500)
        }
    case .bottom:
        VSplitView {
            terminalStack
            SFTPPanelView(service: activeTab.sftpService)
                .frame(minHeight: 150, idealHeight: 260, maxHeight: 500)
        }
    case .hidden:
        terminalStack
    }
}
```

### Pattern 2: SFTPBrowserService — @Observable @MainActor Actor

**What:** One `SFTPBrowserService` per open tab. Owns an sftp subprocess, current path, directory listing, and transfer queue. Spawned when the tab's `SSHConnection.state` transitions to `.connected`. Terminated when the tab closes.

**When to use:** All SFTP data operations. SwiftUI views observe this service directly via `@Observable`.

**Example:**
```swift
// Source: established @Observable @MainActor pattern from TabManager.swift, SnippetStore.swift
@Observable
@MainActor
final class SFTPBrowserService {
    let sessionId: UUID
    private(set) var currentPath: String = "~"
    private(set) var items: [SFTPItem] = []
    private(set) var transfers: [TransferTask] = []
    private(set) var isLoading: Bool = false

    private var channel: SFTPSubprocessChannel?

    init(sessionId: UUID) { self.sessionId = sessionId }

    func connect() async throws {
        let socketPath = SSHArgumentBuilder.controlPath(for: sessionId)
        // Wait for socket file to exist (terminal may still be negotiating ControlMaster)
        try await waitForSocket(socketPath, timeout: 10)
        channel = try SFTPSubprocessChannel(socketPath: socketPath, sessionId: sessionId)
        try await listDirectory(path: "~")
    }

    func listDirectory(path: String) async throws { ... }
    func upload(localURL: URL, toRemotePath: String) async throws -> AsyncThrowingStream<TransferProgress, Error> { ... }
    func download(remotePath: String, toLocalURL: URL) async throws -> AsyncThrowingStream<TransferProgress, Error> { ... }
    func createDirectory(at path: String) async throws { ... }
    func rename(from: String, to: String) async throws { ... }
    func delete(at path: String) async throws { ... }
}
```

### Pattern 3: SFTPSubprocessChannel — sftp subprocess via ControlMaster

**What:** Spawns `/usr/bin/sftp -b - -o ControlMaster=no -o ControlPath=<sock> <user>@<host>`. Writes SFTP batch commands to stdin, reads and parses stdout/stderr for results and progress.

**When to use:** All remote filesystem operations inside `SFTPBrowserService`.

**Key sftp commands used:**
```
ls -la <path>          # directory listing with permissions, size, date
mkdir <path>           # create directory
rename <old> <new>     # rename/move
rm <path>              # delete file
rmdir <path>           # delete directory
put <local> <remote>   # upload
get <remote> <local>   # download
progress               # toggle progress output (OpenSSH 9.0+ on macOS 14)
bye                    # close sftp session
```

**Example:**
```swift
// Source: Foundation.Process pattern established in SSHConnection.swift
final class SFTPSubprocessChannel {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()

    init(socketPath: String, sessionId: UUID) throws {
        let config = // retrieve SSHConfig from session
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sftp")
        process.arguments = [
            "-b", "-",
            "-o", "ControlMaster=no",
            "-o", "ControlPath=\(socketPath)",
            "\(config.username)@\(config.hostname)"
        ]
        process.standardInput  = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe
        try process.run()
    }

    func send(_ command: String) {
        let data = (command + "\n").data(using: .utf8)!
        stdinPipe.fileHandleForWriting.write(data)
    }
}
```

### Pattern 4: TabItem Extension for SFTP State

**What:** Extend `TabItem` with two new fields: `sftpPosition` (per-tab override) and `sftpService` (the live service instance).

**When to use:** `TabManager.openTab(for:)` initialises both fields. ContentView reads them when building the split layout.

```swift
// TabManager.swift additions
struct TabItem: Identifiable {
    let id: UUID
    let sessionId: UUID
    var displayName: String
    let connection: SSHConnection
    // Phase 3 additions:
    var sftpPosition: SFTPPanelPosition   // per-tab override; defaults to @AppStorage global
    let sftpService: SFTPBrowserService   // owned service, started after SSH connect
}

enum SFTPPanelPosition: String {
    case left, right, bottom, hidden
}
```

### Pattern 5: Drag-to-Finder Download (NSFilePromiseProvider)

**What:** SwiftUI `onDrag` cannot produce NSFilePromise items. The file row must register as an AppKit drag source that vends an `NSFilePromiseProvider`. The pattern is: wrap the file row in `NSViewRepresentable`, override `mouseDragged:` on the NSView, and call `beginDraggingSession(with:event:source:)`.

**When to use:** User drags a remote file from the SFTP panel to Finder/Desktop.

```swift
// Source: https://wadetregaskis.com/swiftui-drag-drop-does-not-support-file-promises/
// Pattern: NSViewRepresentable wrapping an NSView subclass that implements NSDraggingSource

class SFTPDragSourceView: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {

    var remoteFile: SFTPItem?
    var sftpService: SFTPBrowserService?

    override func mouseDragged(with event: NSEvent) {
        guard let file = remoteFile else { return }
        let provider = NSFilePromiseProvider(fileType: UTType.data.identifier, delegate: self)
        provider.userInfo = file  // used in fulfillment callback
        let item = NSDraggingItem(pasteboardWriter: provider)
        item.setDraggingFrame(bounds, contents: NSImage(systemSymbolName: "doc", accessibilityDescription: nil))
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                              fileNameForType fileType: String) -> String {
        return remoteFile?.name ?? "download"
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                              writePromiseTo url: URL,
                              completionHandler: @escaping (Error?) -> Void) {
        // Trigger actual download from SFTPBrowserService
        Task {
            do {
                let stream = try await sftpService?.download(remotePath: remoteFile!.path, toLocalURL: url)
                for try await _ in stream ?? EmptyAsyncSequence() { }
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
```

### Pattern 6: Upload Drop Target (NSDraggingDestination)

**What:** The SFTP file list area registers as a drop destination for `public.file-url` items dragged from Finder.

```swift
// Source: https://eclecticlight.co/2024/05/21/swiftui-on-macos-drag-and-drop-and-more/
// SwiftUI .onDrop with DropDelegate handles Finder → panel uploads

struct SFTPDropDelegate: DropDelegate {
    let sftpService: SFTPBrowserService

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    _ = try? await sftpService.upload(localURL: url, toRemotePath: sftpService.currentPath)
                }
            }
        }
        return true
    }
}
```

### Pattern 7: Inline Rename with TextField

**What:** Each file row conditionally shows a `TextField` instead of `Text` when the row is in rename-editing state. `onSubmit` commits the rename; pressing Escape cancels.

```swift
// Source: Swift by Sundell "Building editable lists with SwiftUI" + Apple renameAction API
if item.id == editingId {
    TextField("", text: $pendingName)
        .onSubmit {
            Task { try await sftpService.rename(from: item.path, to: newPath) }
            editingId = nil
        }
        .onKeyPress(.escape) { editingId = nil; return .handled }
} else {
    Text(item.name)
}
```

### Pattern 8: Double-Click to Open (WinSCP Style)

**What:** Download file to `FileManager.default.temporaryDirectory / UUID / filename`, then `NSWorkspace.shared.open(url)` to launch in default app.

```swift
// Source: Apple NSWorkspace documentation
let tempURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent(item.name)
try FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
let stream = try await sftpService.download(remotePath: item.path, toLocalURL: tempURL)
for try await _ in stream { }   // wait for download
NSWorkspace.shared.open(tempURL)
```

### Anti-Patterns to Avoid

- **Using SwiftUI `onDrag` for panel-to-Finder download:** SwiftUI cannot produce NSFilePromise items; Finder will reject the drop. Must use `NSFilePromiseProvider` in AppKit.
- **Loading entire files into memory:** Always stream transfers in chunks (32KB-256KB). Never `Data(contentsOf: remoteURL)` equivalent.
- **Sharing the sftp subprocess between tabs:** Each tab gets its own `SFTPSubprocessChannel`. Multiplexing between sessions on the same subprocess causes command interleaving.
- **Starting SFTPBrowserService before ControlMaster socket exists:** The socket is created by the first SSH handshake. Poll for socket file existence with a brief delay; don't assume it exists immediately on `connection.state == .connected`.
- **Parsing sftp stdout with brittle string matching:** sftp output format is locale-sensitive (dates, sizes). Use `ls -la` and parse the POSIX-compatible long format, or issue `stat` for individual files.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SFTP protocol implementation | Custom SSH channel parser | `/usr/bin/sftp` via Process | Hundreds of edge cases in SSH channel layer; system binary handles all of them |
| Drag-to-Finder file delivery | Custom pasteboard/clipboard code | `NSFilePromiseProvider` | macOS file promise protocol has complex lifecycle; AppKit handles receiver-side completion |
| Split view with draggable divider | Custom NSView drag tracking | `HSplitView` / `VSplitView` | SwiftUI built-in; handles mouse hit-testing, cursor changes, and resize callbacks |
| Temporary file cleanup | Manual `FileManager.removeItem` tracking | Write to `FileManager.default.temporaryDirectory`; OS cleans on reboot | Temp dir semantics on macOS are "cleaned eventually"; don't build a manual cleanup registry |
| File type icons | Custom icon lookup table | `NSWorkspace.shared.icon(forFileType:)` | Returns NSImage matching the system icon for any file extension; covers thousands of types |
| Progress fraction calculation | Custom byte accounting | Track `bytesTransferred / totalBytes` from sftp `progress` output | sftp emits transfer progress lines; parse them rather than maintaining a separate byte counter |

**Key insight:** The `/usr/bin/sftp` subprocess already implements the entire SFTP protocol including resumable transfers, error handling, and progress output. Wrapping it in a `Process` + `Pipe` is ~100 lines; a libssh2-based implementation is 800+ lines with the same failure modes.

---

## Common Pitfalls

### Pitfall 1: ControlMaster Socket Not Yet Ready When SFTPBrowserService Connects

**What goes wrong:** `SFTPBrowserService.connect()` is called as soon as `SSHConnection.state` changes to `.connected`, but the ControlMaster socket file at `/tmp/mobaalt-XXXXXXXX.sock` may not exist yet — `ssh` sets state to connecting-in-progress before the control socket is written.

**Why it happens:** `SSHConnection.start()` sets `state = .connected` immediately after calling `view.startProcess(...)`, but the SSH process still needs to complete its handshake and create the ControlMaster socket. This is a race condition.

**How to avoid:** In `SFTPBrowserService.connect()`, poll for the socket file before spawning the sftp process:
```swift
private func waitForSocket(_ path: String, timeout: TimeInterval) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: path) { return }
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    }
    throw SFTPError.socketTimeout
}
```
**Warning signs:** sftp subprocess exits immediately with "ControlSocket ... does not exist."

---

### Pitfall 2: sftp stdout Parsing is Locale-Sensitive

**What goes wrong:** `ls -la` output date/time fields vary by locale (e.g., "Jan  3" vs "03.01"). Size units can change. Parsing breaks for servers with non-English locales.

**Why it happens:** sftp inherits the locale from the spawned process environment.

**How to avoid:** Set `LANG=C LC_ALL=C` in the sftp subprocess environment, and set the remote server's locale for the session by prepending `export LANG=C LC_ALL=C; ` to the path argument, or use the `lsdir` alternative that returns structured output. The simplest reliable parse: use `ls -la` with `LANG=C` and parse the 9-field POSIX long format (permissions, links, owner, group, size, month, day, time/year, name).

**Warning signs:** Directory listing shows empty `items` array or garbled file names after connecting to a Japanese/Chinese-locale server.

---

### Pitfall 3: SwiftUI View Rebuilds Stall During Large File Transfers

**What goes wrong:** Progress updates (e.g., every 64KB) trigger `@Observable` property changes on `SFTPBrowserService`, which cause the entire `SFTPPanelView` to re-render at high frequency, causing UI jitter.

**Why it happens:** `@Observable` will cause SwiftUI to re-evaluate any view that reads a changed property. If `transfers` array is updated every 64KB for a large file, the view renders at near-frame rate.

**How to avoid:** Throttle progress updates on `MainActor` to at most 10Hz (100ms intervals). Only publish changes to the `transfers` array once per progress interval, not on every chunk:
```swift
private var lastProgressUpdate: Date = .distantPast
private func reportProgress(_ task: inout TransferTask, bytes: Int64) {
    task.bytesTransferred += bytes
    let now = Date()
    if now.timeIntervalSince(lastProgressUpdate) > 0.1 {
        transfers[taskIndex] = task
        lastProgressUpdate = now
    }
}
```

**Warning signs:** CPU spikes to 30%+ during a file transfer while the terminal is idle.

---

### Pitfall 4: sftp Process Does Not Exit After Sending "bye"

**What goes wrong:** When the tab closes, `SFTPBrowserService` sends `bye` to the sftp stdin, but the process does not terminate if the stdin pipe is not also closed. This leaves a zombie sftp process.

**Why it happens:** sftp reads commands from stdin; after `bye`, it expects EOF on stdin to fully terminate. If the `Pipe` write-end is not closed, sftp blocks waiting for more input.

**How to avoid:** After writing `bye\n`, close the write end of the stdin pipe:
```swift
func disconnect() {
    channel?.send("bye")
    channel?.stdinPipe.fileHandleForWriting.closeFile()
    channel?.process.terminate()
}
```
Also register a `terminationHandler` on the `Process` to detect unexpected exits.

**Warning signs:** `ps aux | grep sftp` shows lingering processes after all tabs are closed.

---

### Pitfall 5: Drag Download from Panel Blocks Main Thread

**What goes wrong:** `NSFilePromiseProvider`'s `filePromiseProvider(_:writePromiseTo:completionHandler:)` is called on a background queue by AppKit. If the implementation dispatches back to MainActor to call `SFTPBrowserService`, and `SFTPBrowserService` blocks waiting for sftp output, the entire drag operation hangs.

**Why it happens:** The promise fulfillment callback must write the file synchronously (from AppKit's perspective) before calling `completionHandler`. If the download is async and the Task suspension point crosses the MainActor, deadlock is possible.

**How to avoid:** Implement `filePromiseProvider` using a detached `Task` that does NOT hop to MainActor for the download. Use `SFTPBrowserService` via a non-isolated entry point, or design the service to expose a `nonisolated` download method that creates its own channel. Call `completionHandler` from the Task's completion:
```swift
func filePromiseProvider(_ provider: NSFilePromiseProvider,
                          writePromiseTo url: URL,
                          completionHandler: @escaping (Error?) -> Void) {
    Task.detached { [weak self] in
        do {
            try await self?.sftpService.download(remotePath: ..., toLocalURL: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}
```

---

### Pitfall 6: Per-Tab SFTP Panel Position Not Preserved on Tab Switch

**What goes wrong:** User changes the panel position for Tab A to "Right". When they switch to Tab B and back to Tab A, the panel is back at the global default (Left).

**Why it happens:** If `sftpPosition` is stored as `@State` in the view rather than on `TabItem`, it is reset whenever the view is recreated (which happens with `.id(activeTab.id)` force-recreation on tab switch).

**How to avoid:** `sftpPosition` MUST live on `TabItem` (a value type in `TabManager.tabs`), not in a SwiftUI view. The toolbar position-cycle button mutates `tabManager.tabs[index].sftpPosition` directly.

---

## Code Examples

Verified patterns from official sources and codebase inspection:

### ControlMaster Socket Path (from SSHArgumentBuilder.swift)
```swift
// Source: MobaAlt/Utilities/SSHArgumentBuilder.swift (actual production code)
static func controlPath(for sessionId: UUID) -> String {
    let prefix = String(sessionId.uuidString.prefix(8)).lowercased()
    return "/tmp/mobaalt-\(prefix).sock"
}
```

### HSplitView with Ideal Width
```swift
// Source: Apple SwiftUI HSplitView documentation + community verified pattern
HSplitView {
    SFTPPanelView(service: sftpService)
        .frame(minWidth: 180, idealWidth: 280, maxWidth: 500)
    TerminalStackView(connection: connection)
        .layoutPriority(1)  // terminal gets remaining space
}
```

### Spawn sftp Over ControlMaster Socket
```swift
// Source: sftp(1) man page -o flag + OpenSSH ControlMaster documentation
// /usr/bin/sftp -b - -o ControlMaster=no -o ControlPath=/tmp/mobaalt-XXXXXXXX.sock user@host
process.arguments = [
    "-b", "-",                                    // batch mode: read commands from stdin
    "-o", "ControlMaster=no",                     // slave (don't create new master)
    "-o", "ControlPath=\(socketPath)",            // reuse existing master socket
    "\(username)@\(hostname)"
]
```

### Progress via AsyncThrowingStream
```swift
// Source: Swift community patterns; verified via Swift Forums AsyncStream discussions
func download(remotePath: String, toLocalURL localURL: URL) -> AsyncThrowingStream<TransferProgress, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                // Issue "get remotePath localURL.path" to sftp stdin
                // Parse "Fetching /path/to/file to /local/path" lines from stdout
                // Parse progress lines: "filename   XX%  XXKB  XX.XKB/s ..."
                continuation.yield(TransferProgress(fraction: 0.5, bytesTransferred: 512_000, totalBytes: 1_000_000))
                // ...
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

### @AppStorage for Global SFTP Position Preference
```swift
// Source: Apple @AppStorage documentation; macOS 14+
// In PreferencesView:
@AppStorage("sftpDefaultPosition") private var defaultPosition: SFTPPanelPosition = .left

// In TabManager.openTab(for:):
let position = SFTPPanelPosition(rawValue: UserDefaults.standard.string(forKey: "sftpDefaultPosition") ?? "left") ?? .left
```

### NSWorkspace Double-Click Open
```swift
// Source: Apple NSWorkspace documentation
// Deprecated openFile(_:) → use modern open(_:configuration:completionHandler:)
NSWorkspace.shared.open(
    tempFileURL,
    configuration: NSWorkspace.OpenConfiguration(),
    completionHandler: nil
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NMSSH (ObjC libssh2 wrapper) for SFTP | System /usr/bin/sftp subprocess or mft xcframework | ~2022 (NMSSH unmaintained) | NMSSH is effectively dead; subprocess is the pragmatic choice for this project |
| SwiftUI Transferable for file drag-out | AppKit NSFilePromiseProvider | macOS 13+ (SwiftUI limitation confirmed) | SwiftUI drag-out to Finder requires NSFilePromiseProvider regardless of macOS version |
| Combine-based progress | AsyncThrowingStream | Swift 5.5+ (2021) | AsyncStream is the modern pattern; no Combine dependency needed |
| ProgressKit / NSProgress | Per-transfer struct + AsyncThrowingStream | Swift 5.5+ | Custom struct is simpler and sufficient; no third-party dependency |

**Deprecated/outdated:**
- `NMSSH`: Last significant update ~2020; ObjC wrapper around libssh2; incompatible with Swift concurrency. Do not use.
- `NSWorkspace.openFile(_:)`: Deprecated in macOS 12; use `NSWorkspace.open(_:configuration:completionHandler:)`.
- `UTTypeCreatePreferredIdentifierForTag` (legacy UTI API): Use `UTType` from `UniformTypeIdentifiers` framework (macOS 11+).

---

## Open Questions

1. **sftp `progress` command availability on macOS 14**
   - What we know: OpenSSH 9.0+ added a `progress` toggle command for sftp batch mode. macOS 14 ships OpenSSH 9.x (confirmed via STACK.md macOS 14 note).
   - What's unclear: Exact version of OpenSSH bundled with macOS 14.x Sonoma; whether `progress` output format is stable across patch versions.
   - Recommendation: During Wave 0, run `/usr/bin/sftp -V` on macOS 14 to verify OpenSSH version and test that `progress` command is accepted. If not available, fall back to parsing transfer-completion lines only (less granular progress).

2. **sftp long-listing date format under LANG=C**
   - What we know: POSIX `ls -la` format under LANG=C produces: `permissions links owner group size month day time/year name`. Month is English 3-letter abbreviation.
   - What's unclear: Whether sftp's built-in `ls -la` respects `LANG=C` set on the client, or whether it uses the remote server's locale.
   - Recommendation: Test against a server with a non-English locale early. If server locale bleeds through, parse only permissions, size, and name fields (less susceptible to locale variation) and use `stat` for the modification date.

3. **ControlMaster socket lifecycle vs. SFTPBrowserService connect timing**
   - What we know: SSHArgumentBuilder sets `ControlPersist=no`, meaning the socket is removed when the master SSH process exits.
   - What's unclear: Exact delay between `SSHConnection.state = .connected` and socket file creation on disk.
   - Recommendation: Implement the socket-wait loop (Pattern 2) with a 10-second timeout. Log timing in debug builds to characterise the actual delay on first connect.

---

## Validation Architecture

> `nyquist_validation` is `true` in `.planning/config.json` — this section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`, `#expect`) — already used in all Phase 2 tests |
| Config file | No separate config file; embedded in MobaAltTests Xcode target |
| Quick run command | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SFTP-01 | Panel auto-opens when SSHConnection.state becomes .connected | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPPanelLifecycleTests` | ❌ Wave 0 |
| SFTP-01 | Panel position from @AppStorage global default on new tab | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPPanelLifecycleTests` | ❌ Wave 0 |
| SFTP-01 | Per-tab position override persists on tab switch | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/TabManagerTests` (extend existing) | ✅ (extend) |
| SFTP-02 | listDirectory parses mock sftp stdout into SFTPItem array | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests` | ❌ Wave 0 |
| SFTP-02 | Breadcrumb segments derived from currentPath string | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBreadcrumbTests` | ❌ Wave 0 |
| SFTP-02 | Hidden files filtered when showHidden=false | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests` | ❌ Wave 0 |
| SFTP-03 | upload() emits progress values via AsyncThrowingStream | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPTransferTests` | ❌ Wave 0 |
| SFTP-03 | DropDelegate.performDrop triggers upload for .fileURL items | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPDropDelegateTests` | ❌ Wave 0 |
| SFTP-04 | download() emits progress and writes file to target URL | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPTransferTests` | ❌ Wave 0 |
| SFTP-04 | Double-click calls download then NSWorkspace.open | unit (mock NSWorkspace) | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests` | ❌ Wave 0 |
| SFTP-05 | createDirectory sends correct sftp command | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests` | ❌ Wave 0 |
| SFTP-05 | rename sends correct sftp command | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests` | ❌ Wave 0 |
| SFTP-05 | delete sends correct sftp command | unit | `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests` | ❌ Wave 0 |
| ControlMaster reuse | sftp subprocess uses ControlPath socket (integration) | integration (manual-only, live server) | manual: connect SSH session, verify no re-auth prompt when SFTP panel opens | N/A |
| Drag upload | File dragged from Finder reaches upload() | manual-only (AppKit drag event) | manual: drag a file from Finder onto the SFTP panel | N/A |
| Drag download | NSFilePromiseProvider delivers file to Finder | manual-only (AppKit file promise) | manual: drag a file from SFTP panel to Finder/Desktop | N/A |

### Mock/Stub Approach for SFTP Tests (Without Live Server)

The key is to test `SFTPBrowserService` via a `SFTPChannel` protocol, with a `MockSFTPChannel` in tests:

```swift
// Protocol (production code)
protocol SFTPChannel {
    func send(_ command: String)
    func readLine() async throws -> String
}

// Mock (test target only)
final class MockSFTPChannel: SFTPChannel {
    var commandsSent: [String] = []
    var stubbedLines: [String] = []
    private var lineIndex = 0

    func send(_ command: String) { commandsSent.append(command) }
    func readLine() async throws -> String {
        guard lineIndex < stubbedLines.count else { throw MockError.exhausted }
        defer { lineIndex += 1 }
        return stubbedLines[lineIndex]
    }
}

// Test usage
@Test func testListDirectoryParsesLsOutput() async throws {
    let mock = MockSFTPChannel()
    mock.stubbedLines = [
        "sftp> ",
        "-rw-r--r-- 1 alice staff 1234 Jan  3 12:00 file.txt",
        "drwxr-xr-x 2 alice staff  128 Jan  2 09:30 Documents",
        ""  // end of listing marker
    ]
    let service = SFTPBrowserService(sessionId: UUID(), channel: mock)
    try await service.listDirectory(path: "/home/alice")
    #expect(service.items.count == 2)
    #expect(service.items[0].name == "Documents")  // folders first
    #expect(service.items[1].name == "file.txt")
}
```

### Testing File Transfer Progress UI

Test `TransferTask` model directly — no live transfer needed:

```swift
@Test func testTransferProgressFraction() {
    var task = TransferTask(id: UUID(), remotePath: "/file.zip", totalBytes: 1_000_000)
    task.bytesTransferred = 500_000
    #expect(abs(task.fraction - 0.5) < 0.001)
}

@Test func testMultipleTransfersInQueue() async throws {
    let mock = MockSFTPChannel()
    // Stub progress lines for two concurrent transfers
    let service = SFTPBrowserService(sessionId: UUID(), channel: mock)
    async let t1 = service.upload(localURL: URL(fileURLWithPath: "/a"), toRemotePath: "/remote/a")
    async let t2 = service.upload(localURL: URL(fileURLWithPath: "/b"), toRemotePath: "/remote/b")
    // Verify transfers array contains both tasks
    #expect(service.transfers.count == 2)
}
```

### Testing Drag-and-Drop Upload

SwiftUI `DropDelegate` can be unit tested without UI by calling `performDrop(info:)` directly with a mock `DropInfo`. The mock provides `NSItemProvider` instances loaded with known file URLs:

```swift
@Test func testDropDelegateTriggersUpload() async throws {
    let service = MockSFTPBrowserService()
    let delegate = SFTPDropDelegate(sftpService: service)
    let provider = NSItemProvider(item: URL(fileURLWithPath: "/tmp/test.txt") as NSSecureCoding,
                                   typeIdentifier: UTType.fileURL.identifier)
    // DropInfo can be mocked via a custom conformance or tested via integration
    // For unit test: call the upload path directly
    await service.upload(localURL: URL(fileURLWithPath: "/tmp/test.txt"), toRemotePath: "/remote")
    #expect(service.uploadedURLs.contains(URL(fileURLWithPath: "/tmp/test.txt")))
}
```

Note: Full Finder drag simulation (drag gesture + AppKit event loop) is manual-only. Unit tests cover the service logic; drag mechanics are covered by manual testing.

### Testing ControlMaster Socket Reuse (Integration)

This is inherently a manual integration test requiring a real SSH server:

1. Open a terminal tab to a test server — verify ControlMaster socket at `/tmp/mobaalt-XXXXXXXX.sock`.
2. Observe SFTP panel auto-opens and lists home directory — verify no second password/key prompt appears.
3. Run `ss -x` or `lsof /tmp/mobaalt-XXXXXXXX.sock` on the macOS host — should show two connections (terminal + sftp) over the same socket.
4. Close the terminal tab — verify sftp subprocess exits and socket is removed.

Automated proxy: `SFTPSubprocessChannel` integration test that spawns sftp against a loopback OpenSSH server (started in test setup via `sshd -f /tmp/test_sshd_config -p 2222`) — MEDIUM complexity, defer to Phase 3 verification if time allows.

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme MobaAlt -only-testing MobaAltTests/SFTPBrowserServiceTests -destination 'platform=macOS'`
- **Per wave merge:** `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `MobaAltTests/SFTPBrowserServiceTests.swift` — covers SFTP-02, SFTP-03 (upload progress), SFTP-04 (download progress, double-click), SFTP-05 (mkdir, rename, delete commands); requires `SFTPChannel` protocol + `MockSFTPChannel`
- [ ] `MobaAltTests/SFTPPanelLifecycleTests.swift` — covers SFTP-01 (panel auto-open, position from @AppStorage, per-tab position override)
- [ ] `MobaAltTests/SFTPBreadcrumbTests.swift` — covers SFTP-02 breadcrumb path parsing
- [ ] `MobaAltTests/SFTPTransferTests.swift` — covers transfer progress model (TransferTask fraction, throttling)
- [ ] `MobaAltTests/SFTPDropDelegateTests.swift` — covers upload DropDelegate logic (SFTP-03)
- [ ] `MobaAlt/Services/SFTPBrowserService.swift` — requires `SFTPChannel` protocol with injectable channel for testability

---

## Sources

### Primary (HIGH confidence)
- `MobaAlt/Utilities/SSHArgumentBuilder.swift` — confirms ControlMaster=auto, ControlPath, ControlPersist=no are already in the SSH process args; SFTP can pass `ControlMaster=no` and the same `ControlPath` to multiplex
- `MobaAlt/Services/SSHConnection.swift` — confirms @Observable @MainActor pattern, Process-based subprocess model
- `MobaAlt/Services/TabManager.swift` — confirms TabItem struct pattern; Phase 3 adds sftpPosition + sftpService fields
- `MobaAlt/Views/AppShell/ContentView.swift` — confirms HSplitView insertion point; detail area is currently `VStack { TerminalTabBar; TerminalTabView }`
- sftp(1) man page — `-b -` for stdin batch mode, `-o` for SSH options including ControlMaster=no/ControlPath
- Apple NSWorkspace documentation — `open(_:configuration:completionHandler:)` for WinSCP-style double-click open
- Apple HSplitView/VSplitView — `frame(minWidth:idealWidth:maxWidth:)` for 280px default with drag resize

### Secondary (MEDIUM confidence)
- wadetregaskis.com "SwiftUI drag & drop does not support file promises" (2024) — confirms NSFilePromiseProvider required for Finder drag-out; SwiftUI onDrag insufficient
- eclecticlight.co "SwiftUI on macOS: Drag and drop" (May 2024) — confirms `public.file-url` UTType + DropDelegate pattern for Finder-to-app drops
- Swift Forums "AsyncStream and progress reporting" — confirms AsyncThrowingStream as standard progress pattern
- libssh2-spm GitHub (Lakr233) — active as of Jan 2026 but only 10 commits, 16 stars; no evidence of SFTP-specific Swift API (only libssh2 C re-export)
- mft GitHub (mplpl) — mature SFTP API (MFTSftpConnection), last release Sep 2025, but uses libssh as backend (cannot reuse ControlMaster socket), LGPL-2.1 license, xcframework distribution (no SPM)

### Tertiary (LOW confidence)
- macOS 14 specific OpenSSH version and `progress` command support — not verified; needs runtime check during Wave 0
- sftp `ls -la` date format stability under LANG=C — training data + community reports; verify against real server during integration testing

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — system sftp binary approach is confirmed by Phase 2 patterns; no new dependencies required
- Architecture patterns: HIGH — all patterns derive from existing production code in the codebase + Apple documentation
- Drag-and-drop: MEDIUM-HIGH — SwiftUI limitation confirmed by 2024 authoritative source; NSFilePromiseProvider pattern is established AppKit API
- SFTP parsing: MEDIUM — sftp stdout format well-documented but locale sensitivity needs runtime validation
- Pitfalls: HIGH — derived from actual code inspection (race conditions, process lifecycle) and confirmed macOS behavior

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (30 days; stable macOS APIs)
