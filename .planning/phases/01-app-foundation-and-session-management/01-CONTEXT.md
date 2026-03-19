# Phase 1: App Foundation and Session Management - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the native macOS app shell with session CRUD, folder organization, search, MobaXterm import/export, code signing, and DMG distribution pipeline. No live connections in this phase — that's Phase 2. This phase delivers a fully navigable session manager that persists data and ships as a signed, installable DMG.

</domain>

<decisions>
## Implementation Decisions

### App Layout & Window Structure
- Sidebar **stays visible by default** when connections are open (MobaXterm-style)
- Sidebar can be toggled hidden/shown via **toolbar button AND keyboard shortcut** (⌘⇧L or similar) — required for full-screen work
- Tabs appear **at the top of the content area** (browser-style, above the terminal/content pane)
- **Single-window by default** — all sessions in one window
- Tabs can be **"unpinned"** and torn off into separate windows (for multi-monitor use)
- Sidebar is **resizable**, default width ~220px

### Session Editor UX
- Session create/edit opens as a **modal sheet** (not a slide-in panel)
- Basic fields shown upfront: **name, hostname, port, username, auth method**
- Everything else (port forwarding, X11, logging, etc.) in an **Advanced tab/section**
- A **Wizard mode button** is available in the modal for guided step-by-step entry (type → connection → auth → options)
- **Double-click** a session in sidebar = connect immediately
- Single-click = select; right-click = context menu with Edit / Connect / Duplicate / Delete
- New session: via **toolbar + button**, **right-click context menu in sidebar**, and **⌘N shortcut**
- Session name **auto-fills from hostname** as user types it (can be overridden)
- Password field: **saves to Keychain by default**; a checkbox lets user opt out ("Don't save password")

### Sidebar Visual Design
- Session entries show a **protocol icon** (terminal icon for SSH, screen icon for RDP, eye icon for VNC) with a **subtle color badge** (e.g., green for SSH, blue for RDP, orange for VNC)
- **Text badge ("SSH" / "RDP" / "VNC") appears on hover** — not always visible to keep the list compact
- Session list density is **user-configurable** (compact / comfortable toggle in Preferences)
- Sidebar background uses **macOS system sidebar material** (respects Dark Mode automatically)
- Folders use **macOS system folder icon** with **bold folder name text**
- Sessions within folders are indented, folders have expand/collapse chevrons

### Import Flow (MobaXterm .mxtsessions)
- Import triggered via **File menu → Import Sessions** OR **drag-and-drop a .mxtsessions file** onto the sidebar — both open the same import wizard
- Import wizard shows a **tree preview** of folders and sessions with checkboxes — user can select all, specific folders, or individual sessions before importing
- **Folder structure is preserved exactly** from the .mxtsessions file
- On conflict (same session name exists): **ask the user** — dialog showing conflicting sessions with options: Overwrite / Rename (auto-suffix) / Skip
- After import: **summary sheet** showing "X sessions imported, Y folders created" before wizard closes

### Export Formats
- Export supports **three formats** (user picks in export dialog):
  1. **MobaXterm .mxtsessions** — compatible with Windows MobaXterm (default, primary format)
  2. **JSON** — portable, git-diffable, clean machine-readable format
  3. **HTML summary** — human-readable page with session name, IP/hostname, title, and any notes the user added — intended for forwarding to coworkers
- **Passwords and SSH keys are NEVER included** in any export format
- Export options: **full export** (all sessions) OR **right-click a folder → "Export this folder"** for partial export

### Session Notes Field
- Sessions should have an optional **notes/description field** (used in HTML export and visible in session editor)

### Claude's Discretion
- Exact keyboard shortcut for sidebar toggle (⌘⇧L or similar)
- Internal data storage format (SwiftData or JSON file on disk)
- Exact color values for SSH/RDP/VNC badges
- DMG background image and icon layout
- Error state handling in the import wizard (malformed .mxtsessions file)
- Preferences window layout and organization

</decisions>

<specifics>
## Specific Ideas

- "It should feel like MobaXterm but on Mac" — familiar session tree on the left, tabs on top for open connections
- Sidebar auto-hide must be **both toolbar button and keyboard shortcut** — not one or the other
- Import wizard with tree-level selection (like MobaXterm's own import) is important for coworker adoption — they don't always want everything
- HTML export is specifically for forwarding server info to coworkers who don't use the app (e.g., a list of all lab servers)
- Export format should default to .mxtsessions for maximum compatibility (coworkers on Windows can also use the file)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — greenfield project. No existing components.

### Established Patterns
- macOS 14+ target unlocks `@Observable` macro, `NavigationSplitView`, SwiftData for persistence
- `NavigationSplitView` is the natural container for sidebar + content + optional detail panel
- SwiftData or JSON-backed model store for session persistence (decide at planning time)

### Integration Points
- Phase 2 (SSH terminal) will connect to the session model defined here — `SessionDefinition` type must include all SSH fields
- Phase 4 (RDP/VNC) will also connect to the same session model — model needs protocol-specific subfields or a discriminated union design
- Credentials defined here (opt-in Keychain save) carry through to Phase 2 actual connection logic

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-app-foundation-and-session-management*
*Context gathered: 2026-03-19*
