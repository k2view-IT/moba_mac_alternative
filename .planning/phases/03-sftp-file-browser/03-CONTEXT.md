# Phase 3: SFTP File Browser - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a visual SFTP file browser panel that opens alongside every SSH terminal session. Users can browse the remote directory tree, upload/download files via drag-and-drop, and perform core file operations (create, rename, delete). The SFTP connection rides on the ControlMaster socket established in Phase 2 — no separate authentication required.

</domain>

<decisions>
## Implementation Decisions

### Panel Layout & Position
- **Default position: LEFT** — SFTP panel on the left, terminal on the right (opposite of MobaXterm default, but user's preference)
- Panel is **resizable** — draggable divider between SFTP and terminal
- Default width: **~280px**
- Position is **user-configurable at two levels**:
  1. **Preferences** — sets the global default (Left / Right / Bottom)
  2. **Per-tab toolbar button** — cycles through Left / Right / Bottom / Hidden for the current session; overrides the global default for that tab

### Panel Trigger & Persistence
- **Auto-opens on every SSH connect** — panel appears automatically alongside the terminal
- If user closes the panel, it **re-opens automatically on the next SSH connection** (not remembered as "closed")
- User must explicitly hide it each session, or change the global default in Preferences

### File Browser Design
- **List view with columns**: filename, size, modified date — like Finder list view
- **Sortable columns** (click header to sort)
- **Default sort**: folders first, then files A–Z
- **Breadcrumb path bar at top** — clickable path segments to jump up directories; double-click folders to navigate into them
- **Hidden files (dotfiles)**: hidden by default, toggleable with ⌘Shift+. (same as Finder)

### File Transfer UX
- **Upload**: drag files/folders from Finder onto the SFTP panel → uploads to current directory. Also a toolbar "Upload" button that opens a file picker
- **Download**: drag files from SFTP panel to Finder/Desktop. Also right-click → Download with save dialog
- **Double-click a file**: downloads to a temp folder and opens in the default macOS app (WinSCP-style)
- **Progress display**: slim progress bar + filename at the bottom of the SFTP panel. Multiple simultaneous transfers shown as a queue list. No blocking modal.

### File Operations (Context Menu)
- **Core set**: New File, New Folder, Rename, Delete, Download, Copy Path
- **Inline rename**: click to select, press Enter or click again to edit inline — no dialog
- **Multi-select**: Cmd+click and drag-select for batch download/delete

### Claude's Discretion
- Exact progress bar visual design (color, height, animation)
- How to handle transfer errors (retry logic, error messages)
- Exact ⌘Shift+. keyboard shortcut implementation for hidden files toggle
- Column width defaults and minimum widths
- File type icons (use system NSWorkspace icons vs custom)

</decisions>

<specifics>
## Specific Ideas

- Panel default is LEFT (SFTP) + RIGHT (terminal) — user explicitly chose this as their preference, different from MobaXterm
- "Can be changed in Preferences but can be changed per session with a toolbar button" — both levels of control
- WinSCP-style double-click: download to temp + open locally — familiar to IT users coming from Windows tools
- Progress in panel bottom (not modal, not notification) — keeps workflow uninterrupted

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SSHConnection.swift` — exposes `session: SessionDefinition` and ControlMaster socket path via `SSHArgumentBuilder.controlPath(for: session.id)`; SFTP must reuse this socket
- `TabManager.swift` — `activeConnections: [SSHConnection]` — SFTP panel binds to the active tab's SSHConnection
- `ContentView.swift` — `NavigationSplitView` detail area currently holds `TerminalTabBar + TerminalTabView`; Phase 3 wraps this in an `HSplitView` (or `VSplitView` for bottom layout)
- `TabItem` struct in TabManager — needs an `isSFTPVisible: Bool` and `sftpPosition: SFTPPanelPosition` field to track per-tab panel state

### Established Patterns
- `@Observable @MainActor` class pattern for services (TabManager, SSHConnection, SnippetStore)
- `NSViewRepresentable` for AppKit views that SwiftUI can't render natively (TerminalTabView → expect same for SFTP file list)
- `EnvironmentKey` pattern for actor-based services injected into SwiftUI
- `SSHArgumentBuilder.controlPath(for:)` — returns the ControlMaster socket path; SFTP subprocess must use `-o ControlPath=<path> -o ControlMaster=no` to piggyback

### Integration Points
- SFTP panel connects to `TabManager.activeTabId` to know which session's remote filesystem to show
- Panel position state lives on `TabItem` (per-tab override) + `@AppStorage("sftpDefaultPosition")` (global Preferences default)
- SFTP backend: spawn `/usr/bin/sftp -b -` subprocess with ControlMaster socket, or use `libssh2` Swift binding — planner/researcher decides based on Phase 2 ControlMaster socket availability
- Phase 3 wraps the existing terminal view in a split container — `ContentView.swift` detail area layout changes

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-sftp-file-browser*
*Context gathered: 2026-03-22*
