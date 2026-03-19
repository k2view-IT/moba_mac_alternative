# Phase 1: App Foundation and Session Management - Research

**Researched:** 2026-03-19
**Domain:** Native macOS SwiftUI app scaffold, session CRUD, folder hierarchy, import/export, code signing, DMG distribution
**Confidence:** HIGH (well-documented Apple APIs, format reverse-engineered by community)

## Summary

Phase 1 builds the entire app shell: Xcode project with Hardened Runtime (no App Sandbox), NavigationSplitView sidebar with folder tree, session CRUD with modal editor, search/filter, MobaXterm .mxtsessions import/export, JSON/HTML export, and a signed/notarizable DMG. No live connections -- this is the data and UI foundation.

The most critical finding is that **SwiftData must NOT be used** for session persistence. SwiftData has a confirmed bug where it randomly reorders array elements when loading from storage (it fails to record element order in SQLite). This directly breaks session ordering within folders and folder sort order -- both core to this phase. Use JSON files with atomic writes instead. This is simpler, crash-safe, fully transparent, and avoids SwiftData's auto-save timing issues (changes can be silently lost on app quit).

The .mxtsessions file format is well-documented via community reverse engineering. It is INI-formatted with `%`-delimited fields per session line, and session types are identified by numeric codes (SSH=0, RDP=4, VNC=5). No SPM package exists for parsing this format -- we must write a custom parser, but the format is straightforward.

**Primary recommendation:** JSON persistence with atomic writes. Custom .mxtsessions parser. Hardened Runtime with minimal entitlements (no App Sandbox). DisclosureGroup-based sidebar with onDrag/onDrop for folder reordering. String interpolation for HTML export.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Sidebar stays visible by default; togglable via toolbar button AND keyboard shortcut
- Tabs at top of content area (browser-style)
- Single-window by default; tabs can be torn off into separate windows for multi-monitor
- Sidebar is resizable, default ~220px
- Session create/edit as modal sheet with basic fields upfront, Advanced tab/section for rest
- Wizard mode button in modal for guided step-by-step entry
- Double-click = connect; single-click = select; right-click = context menu (Edit/Connect/Duplicate/Delete)
- New session via toolbar + button, right-click context menu, Cmd+N shortcut
- Session name auto-fills from hostname
- Password saves to Keychain by default; checkbox to opt out
- Protocol icons (terminal=SSH, screen=RDP, eye=VNC) with color badges; text badge on hover
- Session density: user-configurable (compact/comfortable) in Preferences
- System sidebar material (respects Dark Mode)
- Folders: system folder icon, bold name, expand/collapse chevrons, indented children
- Import via File menu OR drag-and-drop .mxtsessions onto sidebar; both open import wizard
- Import wizard: tree preview with checkboxes (select all, folder, individual)
- Folder structure preserved from .mxtsessions
- Conflict handling: dialog with Overwrite/Rename(auto-suffix)/Skip per conflict
- Post-import summary sheet
- Export: 3 formats -- .mxtsessions (default), JSON, HTML summary
- Passwords and SSH keys NEVER in exports
- Export: full export OR right-click folder -> "Export this folder"
- Sessions have optional notes/description field

### Claude's Discretion
- Exact keyboard shortcut for sidebar toggle (recommend Cmd+Shift+L)
- Internal data storage format -- **DECIDED: JSON files** (see SwiftData findings below)
- Exact color values for SSH/RDP/VNC badges
- DMG background image and icon layout
- Error handling for malformed .mxtsessions files
- Preferences window layout and organization

### Deferred Ideas (OUT OF SCOPE)
- None -- discussion stayed within phase scope.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SESS-01 | Create saved session (SSH/RDP/VNC) with name, hostname, port, username, auth method | Session model design, modal sheet editor, JSON persistence pattern |
| SESS-02 | Organize sessions into nested folders in sidebar | DisclosureGroup-based tree, onDrag/onDrop reordering, SessionFolder model |
| SESS-03 | Search/filter saved sessions by name or hostname | SwiftUI searchable() modifier on NavigationSplitView |
| SESS-04 | Import from MobaXterm .mxtsessions file | .mxtsessions format specification (INI + % delimiters), custom parser |
| SESS-05 | Export to portable file for backup/sharing | 3 formats: .mxtsessions writer, JSON export, HTML template generation |
| DIST-01 | Notarized, code-signed DMG installer | create-dmg + xcrun notarytool pipeline, Developer ID signing |
| DIST-02 | macOS 14 (Sonoma) minimum deployment target | Swift 5.9+, @Observable, NavigationSplitView, all APIs available |
| DIST-03 | Hardened Runtime without App Sandbox | Minimal entitlements.plist, validated process spawning + Keychain access |

</phase_requirements>

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| Swift | 5.9+ | Primary language | Required; modern concurrency, @Observable macro |
| SwiftUI | macOS 14+ | UI framework | NavigationSplitView, sheets, searchable, native macOS look |
| AppKit (interop) | macOS 14+ | Window management, drag targets | NSWindow tabbing, NSViewRepresentable (future phases), file drop |
| Foundation | macOS 14+ | JSON coding, Process, FileManager | Codable, atomic writes, file I/O |
| Security.framework | macOS 14+ | Keychain access | Password storage for sessions (opt-in) |
| UniformTypeIdentifiers | macOS 14+ | UTType for drag/drop and file dialogs | Required for .mxtsessions file handling |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| create-dmg | latest (Homebrew) | DMG packaging with background/icon layout | Distribution build script |
| xcrun notarytool | Xcode 15+ | Notarization submission and stapling | After archive + signing |
| xcodebuild | Xcode 15+ | Archive and export | CI/CD build pipeline |

### Alternatives Considered
| Instead of | Could Use | Why NOT |
|------------|-----------|---------|
| JSON files | SwiftData | SwiftData has a confirmed bug: randomly reorders arrays on load. Also: auto-save unreliable (changes lost on quit), relationship bugs, migration complexity. JSON is simpler, transparent, crash-safe with atomic writes. |
| JSON files | Core Data | Overkill for <1000 sessions. More boilerplate than JSON. Migration overhead. |
| JSON files | SQLite (GRDB) | Adds dependency for a simple flat data model. JSON sufficient for v1 scale. |
| Custom .mxtsessions parser | Perfect-INIParser (SPM) | .mxtsessions is not standard INI -- it uses `%`-delimited fields within values and special encoding rules. A generic INI parser cannot handle the field extraction. Custom parser needed. |

**Installation (dev environment):**
```bash
# Prerequisites
# - Xcode 15+ with Command Line Tools
# - macOS 14 (Sonoma) or later
# - Apple Developer ID certificate for signing

# Distribution tooling
brew install create-dmg
```

## Architecture Patterns

### Recommended Project Structure
```
MobaAlt/
  MobaAltApp.swift                 # @main, WindowGroup, app-level state
  Models/
    SessionDefinition.swift        # Session model (SSH/RDP/VNC fields)
    SessionFolder.swift            # Folder hierarchy model
    ConnectionProtocol.swift       # Enum: ssh, rdp, vnc with config structs
    SessionLibrary.swift           # In-memory session + folder collection
  Views/
    AppShell/
      ContentView.swift            # NavigationSplitView (sidebar + detail)
      SidebarView.swift            # Folder tree + session list
    Sidebar/
      FolderRowView.swift          # Folder disclosure row
      SessionRowView.swift         # Session row with protocol icon + badge
      SessionSearchView.swift      # Search bar integration
    Editor/
      SessionEditorSheet.swift     # Modal create/edit form
      SessionEditorBasicTab.swift  # Name, host, port, user, auth
      SessionEditorAdvancedTab.swift # Notes, extra options
      SessionWizardView.swift      # Step-by-step guided entry
    Import/
      ImportWizardSheet.swift      # Tree preview with checkboxes
      ImportConflictSheet.swift    # Overwrite/Rename/Skip dialog
      ImportSummarySheet.swift     # Post-import results
    Export/
      ExportDialogSheet.swift      # Format picker + scope
    Preferences/
      PreferencesView.swift        # App preferences (density, shortcut)
  Services/
    SessionStore.swift             # JSON persistence actor (load/save/backup)
    KeychainManager.swift          # Security.framework wrapper for passwords
    MXTSessionsParser.swift        # .mxtsessions import parser
    MXTSessionsWriter.swift        # .mxtsessions export writer
    JSONExporter.swift             # JSON export
    HTMLExporter.swift             # HTML summary export
  Utilities/
    AtomicFileWriter.swift         # Crash-safe JSON writes
    SessionConflictResolver.swift  # Import conflict detection
  Resources/
    MobaAlt.entitlements           # Hardened Runtime entitlements
```

### Pattern 1: JSON Persistence with Atomic Writes
**What:** Store all sessions and folders as Codable structs in JSON files with atomic writes.
**When to use:** Always -- this is the primary persistence strategy for Phase 1.
**Why:** Crash-safe (atomic rename), inspectable, no framework bugs, trivial to implement.

```swift
// Source: Apple Foundation docs + atomic write best practice
actor SessionStore {
    private let sessionsURL: URL  // ~/Library/Application Support/MobaAlt/sessions.json
    private let foldersURL: URL   // ~/Library/Application Support/MobaAlt/folders.json

    func save(sessions: [SessionDefinition], folders: [SessionFolder]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Backup before write
        try? FileManager.default.copyItem(at: sessionsURL, to: sessionsURL.appendingPathExtension("backup"))

        // Atomic write -- writes to temp file, then renames
        let sessionData = try encoder.encode(sessions)
        try sessionData.write(to: sessionsURL, options: .atomic)

        let folderData = try encoder.encode(folders)
        try folderData.write(to: foldersURL, options: .atomic)
    }

    func load() throws -> (sessions: [SessionDefinition], folders: [SessionFolder]) {
        let decoder = JSONDecoder()
        let sessionData = try Data(contentsOf: sessionsURL)
        let folderData = try Data(contentsOf: foldersURL)
        return (
            try decoder.decode([SessionDefinition].self, from: sessionData),
            try decoder.decode([SessionFolder].self, from: folderData)
        )
    }
}
```

### Pattern 2: Hierarchical Sidebar with DisclosureGroup + Drag/Drop
**What:** Build the folder tree using recursive DisclosureGroup views (not List with children) to enable drag-and-drop between folders.
**When to use:** For the sidebar session browser.
**Why:** SwiftUI's `List(children:)` does NOT support `.onDrag`/`.onDrop`. DisclosureGroup + ForEach does. This is the proven approach for editable tree views on macOS.

```swift
// Source: community pattern for draggable hierarchical lists
// Reference: github.com/shufflingB/swiftui-macos-tree-list-demo
struct FolderTreeView: View {
    let folder: SessionFolder
    let allFolders: [SessionFolder]
    let sessions: [SessionDefinition]
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Child folders (recursive)
            ForEach(childFolders) { child in
                FolderTreeView(folder: child, allFolders: allFolders, sessions: sessions)
            }
            // Sessions in this folder
            ForEach(sessionsInFolder) { session in
                SessionRowView(session: session)
                    .onDrag { NSItemProvider(object: session.id.uuidString as NSString) }
            }
        } label: {
            FolderRowView(folder: folder)
                .onDrop(of: [.text], delegate: FolderDropDelegate(targetFolder: folder))
        }
    }
}
```

### Pattern 3: MobaXterm .mxtsessions Parser
**What:** Custom parser for the INI-like .mxtsessions format with `%`-delimited fields.
**When to use:** Import feature (SESS-04).
**Why:** No existing library handles this format. The format is well-documented but non-standard.

```swift
// Source: reverse-engineered format from community gist
// Reference: gist.github.com/Ruzgfpegk/ab597838e4abbe8de30d7224afd062ea
struct MXTSessionsParser {
    struct ParseResult {
        var folders: [String]  // folder paths like "Folder1\\Subfolder"
        var sessions: [(folder: String, session: SessionDefinition)]
        var errors: [ParseError]  // malformed lines
    }

    func parse(data: Data) throws -> ParseResult {
        // 1. Decode as Windows-1252 (CP1252), fallback to UTF-8
        guard let content = String(data: data, encoding: .windowsCP1252)
                          ?? String(data: data, encoding: .utf8) else {
            throw ParseError.invalidEncoding
        }

        // 2. Split into INI sections: [Bookmarks], [Bookmarks_1], etc.
        // 3. For each section, read SubRep (folder path) and ImgNum
        // 4. Parse session lines: Name=#iconNum#group1#group2#tabMode#comment#color
        //    where group1 fields are %-delimited
        // 5. Field 0 of group1 = session type: 0=SSH, 4=RDP, 5=VNC
        // 6. Decode special encodings: __PTVIRG__ -> ;, __DBLQUO__ -> ", __PIPE__ -> |

        // SSH (type 0): host=field[1], port=field[2], username=field[3]
        // RDP (type 4): host=field[1], port=field[2]
        // VNC (type 5): host=field[1], port=field[2]
    }
}
```

### Pattern 4: Hardened Runtime Entitlements (No App Sandbox)
**What:** Minimal entitlements for a non-sandboxed app that spawns processes and accesses Keychain.
**When to use:** Day 1 project setup -- never change this after.

```xml
<!-- MobaAlt.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime is enabled in Xcode build settings, not here -->
    <!-- App Sandbox is NOT enabled (no com.apple.security.app-sandbox key) -->

    <!-- No special entitlements needed for a non-sandboxed Hardened Runtime app to:
         - Spawn child processes (/usr/bin/ssh) via Foundation.Process
         - Access Keychain via Security.framework
         - Read/write user files
         These are all allowed by default without App Sandbox.

         Only add entitlements if specific Hardened Runtime restrictions block functionality:
    -->

    <!-- May be needed if SwiftTerm or JIT code requires it (test first without): -->
    <!-- <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/> -->
</dict>
</plist>
```

**Key insight:** A non-sandboxed app with Hardened Runtime does NOT need entitlements for process spawning or Keychain access. These are restricted only by App Sandbox. Hardened Runtime mainly restricts: JIT, unsigned memory pages, dynamic library loading, and DYLD environment variables. Start with an EMPTY entitlements file and add only what testing proves necessary.

### Pattern 5: Tab Tearoff via NSWindow Tabbing
**What:** Use AppKit's native window tabbing for tab tearoff/multi-window support.
**When to use:** Single-window by default; tabs can be dragged out to separate windows.

```swift
// In AppDelegate or app initialization:
// Enable automatic window tabbing (macOS default behavior)
// NSWindow.allowsAutomaticWindowTabbing = true  // this is already the default

// To add a new tab to the current window:
// let newWindow = NSWindow(...)
// NSApp.keyWindow?.addTabbedWindow(newWindow, ordered: .above)

// Note: For Phase 1, tabs are WITHIN the content area (not native window tabs).
// Tab tearoff is a future enhancement. Phase 1 delivers in-app tab bar UI only.
// Native NSWindow tabbing can be layered on later without architecture changes.
```

### Anti-Patterns to Avoid
- **SwiftData for ordered collections:** Randomly reorders arrays. Use JSON with explicit sortOrder fields.
- **List(children:) with onDrag:** Does not work on macOS. Use DisclosureGroup instead.
- **Storing credentials in session JSON:** Never. Use CredentialReference (UUID only) pointing to Keychain.
- **Non-atomic file writes:** `String.write(to:)` without `.atomic` can corrupt on crash. Always use `.atomic`.
- **Hardcoded app paths:** Never use `/System/Library/CoreServices/Screen Sharing.app`. Use bundle IDs and URL schemes.
- **Global DISPLAY variable:** Let SSH manage X11 forwarding per-session.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON encoding/decoding | Custom serializer | Foundation JSONEncoder/JSONDecoder + Codable | Type-safe, handles optionals, dates, UUIDs natively |
| Keychain access | Raw C API calls everywhere | Thin KeychainManager actor (~100 lines) wrapping SecItem* | Wrap once, use everywhere; the C API is verbose but straightforward |
| DMG creation | Manual hdiutil scripting | create-dmg (Homebrew) | Handles background images, icon positioning, /Applications symlink, signing |
| Notarization | Manual xcrun altool | xcrun notarytool + store-credentials | altool is deprecated; notarytool is current standard with --wait flag |
| File open/save dialogs | Custom file browser | NSOpenPanel / NSSavePanel | Native macOS dialogs, sandboxing-compatible, recent folders, sidebar shortcuts |
| INI parsing for .mxtsessions | Generic INI parser library | Custom parser (~150 lines) | .mxtsessions is NOT standard INI; uses %-delimited sub-fields and special encoding |

**Key insight:** The .mxtsessions format is unique enough that no generic parser handles it. But it is simple enough that a custom parser is ~150 lines of Swift string manipulation.

## Common Pitfalls

### Pitfall 1: SwiftData Array Reordering Bug
**What goes wrong:** SwiftData randomly reorders arrays when loading from SQLite. Session order within folders and folder sort order are corrupted.
**Why it happens:** SwiftData fails to record element order in its SQLite storage. This is a confirmed framework bug present in macOS 14 and 15.
**How to avoid:** Do not use SwiftData. Use JSON files with explicit `sortOrder: Int` fields on both SessionDefinition and SessionFolder.
**Warning signs:** Sessions appear in wrong order after app restart; folders shuffle position.

### Pitfall 2: Non-Atomic JSON Writes Corrupt Data on Crash
**What goes wrong:** App crashes or force-quits during a JSON write, truncating the file. All saved sessions lost.
**Why it happens:** Regular file writes are not atomic -- they write in-place and can be interrupted.
**How to avoid:** Always use `Data.write(to:options:.atomic)`. Keep a `.backup` copy before every write. Implement recovery: if primary file is corrupt, load from backup.
**Warning signs:** Empty or truncated sessions.json after a crash.

### Pitfall 3: Wrong Entitlements Block Everything Downstream
**What goes wrong:** App Sandbox accidentally enabled, or wrong entitlements prevent SSH process spawning or Keychain access in later phases.
**Why it happens:** Default Xcode project templates may enable App Sandbox. Developers add entitlements they do not need.
**How to avoid:** Start with Hardened Runtime ON and App Sandbox OFF. Use an empty or minimal entitlements file. Validate in Phase 1 by: (1) spawning a child process via Foundation.Process, (2) writing/reading a Keychain item, (3) building a signed archive and running on a clean user account.
**Warning signs:** "Operation not permitted" errors; Keychain prompts never appearing; child processes exiting immediately.

### Pitfall 4: .mxtsessions Encoding Gotchas
**What goes wrong:** Import fails on non-ASCII characters, special characters are garbled, or fields are misaligned.
**Why it happens:** .mxtsessions uses Windows-1252 encoding (not UTF-8). Special characters have custom escape sequences: `;` becomes `__PTVIRG__`, `"` becomes `__DBLQUO__`, `|` becomes `__PIPE__`, `#` becomes `__DIEZE__`. Field counts vary by MobaXterm version (v23.6 vs v24.0+ have different field counts).
**How to avoid:** Decode as Windows-1252 first, UTF-8 fallback. Handle all escape sequences. Parse fields by index with fallback defaults for missing fields (older versions). Log and skip malformed lines rather than failing the entire import.
**Warning signs:** Garbled hostnames, missing sessions, crash on import.

### Pitfall 5: Drag-and-Drop in Hierarchical Lists
**What goes wrong:** SwiftUI's `List(children:)` parameter does not support `.onMove` or `.onDrag`. Developers waste time trying to make it work.
**Why it happens:** Apple's implementation limitation. `ForEach` supports `.onMove` but cannot be used with hierarchical `children:` parameter. Only flat lists support move gestures natively.
**How to avoid:** Use recursive `DisclosureGroup` + `ForEach` pattern. Implement drag with `.onDrag` (NSItemProvider encoding session/folder ID) and drop with `.onDrop` (FolderDropDelegate that calls SessionStore to move items).
**Warning signs:** Drag handles not appearing; items not droppable between folders.

### Pitfall 6: Notarization Fails at Distribution Time
**What goes wrong:** App builds and runs locally but Gatekeeper blocks the DMG on a clean Mac.
**Why it happens:** Notarization deferred to "later"; Developer ID certificate not configured; DMG not stapled.
**How to avoid:** Set up the full signing + notarization pipeline in Phase 1. Script: archive -> sign with Developer ID -> create DMG -> sign DMG -> notarytool submit --wait -> staple. Test on a different macOS user account (not the developer account).
**Warning signs:** "App is damaged" on download; Gatekeeper warning dialogs.

## Code Examples

### Session Data Model
```swift
// Verified pattern: Codable structs with explicit sort ordering
import Foundation

enum ConnectionProtocol: Codable, Hashable {
    case ssh(SSHConfig)
    case rdp(RDPConfig)
    case vnc(VNCConfig)

    var protocolName: String {
        switch self {
        case .ssh: return "SSH"
        case .rdp: return "RDP"
        case .vnc: return "VNC"
        }
    }
}

struct SessionDefinition: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderId: UUID?           // nil = root level
    var protocolConfig: ConnectionProtocol
    var notes: String             // optional notes/description
    var sortOrder: Int            // explicit ordering (NOT relying on array position)
    var createdAt: Date
    var lastConnected: Date?

    // Credential is referenced by session ID in Keychain, not stored here
}

struct SSHConfig: Codable, Hashable {
    var hostname: String
    var port: Int = 22
    var username: String = ""
    var authMethod: SSHAuthMethod = .password
    var x11Forwarding: Bool = false
    var agentForwarding: Bool = false
    // Future phases add: jumpHost, portForwarding rules, etc.
}

struct RDPConfig: Codable, Hashable {
    var hostname: String
    var port: Int = 3389
    var username: String = ""
    var domain: String = ""
}

struct VNCConfig: Codable, Hashable {
    var hostname: String
    var port: Int = 5900
}

enum SSHAuthMethod: Codable, Hashable {
    case password
    case privateKey(path: String)
    case agent
}

struct SessionFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var parentId: UUID?           // nil = root
    var sortOrder: Int            // explicit ordering
    var isExpanded: Bool = true   // UI state persisted
}
```

### HTML Export via String Interpolation
```swift
// Source: Swift multiline string interpolation (standard approach)
struct HTMLExporter {
    func export(sessions: [SessionDefinition], folders: [SessionFolder]) -> String {
        let rows = sessions.map { session in
            let proto = session.protocolConfig.protocolName
            let host: String
            switch session.protocolConfig {
            case .ssh(let c): host = "\(c.hostname):\(c.port)"
            case .rdp(let c): host = "\(c.hostname):\(c.port)"
            case .vnc(let c): host = "\(c.hostname):\(c.port)"
            }
            let notes = session.notes.isEmpty ? "" : session.notes
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
            return """
            <tr>
              <td>\(proto)</td>
              <td>\(session.name)</td>
              <td>\(host)</td>
              <td>\(notes)</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html><head>
          <meta charset="utf-8">
          <title>Session List</title>
          <style>
            body { font-family: -apple-system, system-ui, sans-serif; margin: 2em; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background: #f5f5f5; }
          </style>
        </head><body>
          <h1>Session List</h1>
          <table>
            <tr><th>Type</th><th>Name</th><th>Host</th><th>Notes</th></tr>
            \(rows)
          </table>
          <p><em>Exported from MobaAlt on \(Date().formatted())</em></p>
        </body></html>
        """
    }
}
```

### DMG Build + Notarization Script
```bash
#!/bin/bash
set -euo pipefail

APP_NAME="MobaAlt"
SCHEME="MobaAlt"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
APP_PATH="build/${APP_NAME}.app"
DMG_PATH="build/${APP_NAME}.dmg"
TEAM_ID="YOUR_TEAM_ID"
KEYCHAIN_PROFILE="notarytool-profile"  # stored via: xcrun notarytool store-credentials

# 1. Archive
xcodebuild archive \
  -scheme "$SCHEME" \
  -archivePath "$ARCHIVE_PATH" \
  -configuration Release

# 2. Export (signed with Developer ID)
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "build/" \
  -exportOptionsPlist ExportOptions.plist

# 3. Create DMG
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 150 190 \
  --app-drop-link 450 190 \
  "$DMG_PATH" \
  "$APP_PATH"

# 4. Sign DMG
codesign --sign "Developer ID Application: Your Name ($TEAM_ID)" "$DMG_PATH"

# 5. Notarize (waits for Apple's response)
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

# 6. Staple ticket to DMG
xcrun stapler staple "$DMG_PATH"

echo "Done: $DMG_PATH is signed, notarized, and stapled."
```

## .mxtsessions File Format Specification

This section documents the reverse-engineered .mxtsessions format for the import/export parser implementation.

### Overall Structure
- **Encoding:** Windows-1252 (CP1252), fallback UTF-8-without-BOM
- **Line endings:** CRLF (Windows)
- **Format:** INI-like with sections

### Sections
- `[Bookmarks]` -- root folder ("User sessions"), with `SubRep=` (empty) and `ImgNum=42`
- `[Bookmarks_1]`, `[Bookmarks_2]`, etc. -- subfolders, with `SubRep=FolderName` or `SubRep=Parent\\Child` for nesting

### Session Line Format
```
SessionName=#IconNum#Group1#Group2#TabMode#Comments#TabColor
```

Where:
- **IconNum:** Visual icon (109=SSH, 91=RDP, 128=VNC, 140=SFTP)
- **Group1:** `%`-delimited session fields (type-specific)
- **Group2:** `%`-delimited terminal settings (font, colors, charset)
- **TabMode:** 0=normal, 1=detached, 2=maximized detached, 3=fullscreen
- **Comments:** Text with `#` replaced by `__DIEZE__`
- **TabColor:** Custom tab color value

### Session Type Codes (Group1, field index 0)
| Code | Protocol |
|------|----------|
| 0 | SSH |
| 4 | RDP |
| 5 | VNC |
| 7 | SFTP |
| 11 | Browser |

### SSH Fields (Type 0, Group1 `%`-delimited)
| Index | Field | Default |
|-------|-------|---------|
| 0 | Session type | 0 |
| 1 | Remote host | (required) |
| 2 | Port | 22 |
| 3 | Username | (empty) |
| 5 | X11 forwarding | 0 (-1=enabled) |
| 7 | Execute command | (empty) |
| 8-10 | Gateway host/port/user | (empty, pipe-separated for multiple) |
| 14 | Private key path | (empty, `_CurrentDrive_` replaces `C:`) |

### RDP Fields (Type 4, Group1 `%`-delimited)
| Index | Field | Default |
|-------|-------|---------|
| 0 | Session type | 4 |
| 1 | Remote host | (required) |
| 2 | Port | 3389 |
| 10 | Resolution | 0 (fit terminal) |

### VNC Fields (Type 5, Group1 `%`-delimited)
| Index | Field | Default |
|-------|-------|---------|
| 0 | Session type | 5 |
| 1 | Remote host | (required) |
| 2 | Port | 5900 |
| 4 | View-only mode | 0 |

### Special Encoding Rules
| In file | Decoded as |
|---------|-----------|
| `__PTVIRG__` | `;` (semicolon) |
| `__DBLQUO__` | `"` (double quote) |
| `__PIPE__` | `\|` (pipe) |
| `__DIEZE__` | `#` (hash, comments field only) |
| `__PERCENT__` | `%` (percent, proxy commands only) |
| `_CurrentDrive_` | `C:` (Windows drive letter in key paths) |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ObservableObject + @Published | @Observable macro | macOS 14 / WWDC 2023 | Simpler view models, no @Published boilerplate, better performance |
| NavigationView | NavigationSplitView | macOS 13 / WWDC 2022 | Proper 2/3-column layout for macOS sidebar apps |
| xcrun altool (notarization) | xcrun notarytool | Xcode 13 (2021) | altool deprecated; notarytool is current standard |
| SwiftData (persistence) | JSON + Codable (for ordered data) | Ongoing | SwiftData array ordering bug makes it unsuitable for ordered collections |
| Core Data | SwiftData | macOS 14 / WWDC 2023 | SwiftData is Apple's direction, but JSON preferred here due to bugs |

**Deprecated/outdated:**
- `xcrun altool` for notarization -- use `xcrun notarytool` instead
- `ObservableObject` -- use `@Observable` macro on macOS 14+
- `NavigationView` -- use `NavigationSplitView` on macOS 13+

## Open Questions

1. **Developer ID Certificate availability**
   - What we know: Notarization requires a paid Apple Developer Program membership ($99/year) and a Developer ID certificate
   - What's unclear: Whether the project owner has this set up already
   - Recommendation: Verify Developer ID availability at Phase 1 start. If not available, defer notarization validation but keep the script ready. App can still be distributed unsigned with `xattr -cr` instructions for the technical target audience.

2. **Exact .mxtsessions field count by version**
   - What we know: Version 23.6 and 24.0+ have different field counts (SSH: 35 fields in v24.0+)
   - What's unclear: Which MobaXterm versions the user's team actually exports from
   - Recommendation: Parse flexibly -- read available fields, use defaults for missing ones. Log warnings for unexpected field counts but do not fail.

3. **Tab tearoff timing**
   - What we know: User wants tab tearoff for multi-monitor. NSWindow tabbing API supports this natively.
   - What's unclear: Whether this needs to ship in Phase 1 or can wait
   - Recommendation: Phase 1 delivers in-app tab bar UI only (for session management, not connections). Tab tearoff can be added when actual terminal tabs exist (Phase 2). The architecture supports it without changes.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (macOS 14+, Swift 5.9+) + XCTest |
| Config file | None -- Wave 0 (greenfield project, Xcode creates test targets) |
| Quick run command | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-01 | Create/save session with all fields | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/SessionStoreTests/testCreateSession` | Wave 0 |
| SESS-02 | Organize sessions in nested folders | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/SessionStoreTests/testFolderHierarchy` | Wave 0 |
| SESS-03 | Search/filter by name or hostname | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/SessionLibraryTests/testSearch` | Wave 0 |
| SESS-04 | Import .mxtsessions file | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/MXTParserTests` | Wave 0 |
| SESS-05 | Export to 3 formats | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/ExporterTests` | Wave 0 |
| DIST-01 | DMG is signed and notarizable | manual-only | Run build script + test on clean account | N/A |
| DIST-02 | macOS 14 minimum target | unit | Xcode build setting validation (deployment target in project) | N/A |
| DIST-03 | Hardened Runtime, no sandbox, process spawn works | smoke | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/EntitlementTests/testProcessSpawn` | Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green + DMG tested on clean account

### Wave 0 Gaps
- [ ] Xcode project with test target (`MobaAltTests/`)
- [ ] `MobaAltTests/SessionStoreTests.swift` -- CRUD, persistence, ordering
- [ ] `MobaAltTests/MXTParserTests.swift` -- .mxtsessions parsing with sample files
- [ ] `MobaAltTests/ExporterTests.swift` -- JSON, HTML, .mxtsessions export
- [ ] `MobaAltTests/EntitlementTests.swift` -- smoke test: spawn Process, access Keychain
- [ ] `MobaAltTests/Fixtures/` -- sample .mxtsessions files for import testing
- [ ] Framework: Swift Testing (@Test macro) is preferred; XCTest as fallback

## Sources

### Primary (HIGH confidence)
- Apple Developer Docs: NavigationSplitView, @Observable, Codable, Data.write(options:.atomic), Security.framework Keychain Services
- Apple Developer Docs: Hardened Runtime configuration, code signing, notarization
- [.mxtsessions file format reverse-engineered specification](https://gist.github.com/Ruzgfpegk/ab597838e4abbe8de30d7224afd062ea) -- comprehensive field-by-field documentation
- [create-dmg](https://github.com/create-dmg/create-dmg) -- standard DMG creation tool
- [xcrun notarytool documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### Secondary (MEDIUM confidence)
- [SwiftData pitfalls (Wade Tregaskis)](https://wadetregaskis.com/swiftdata-pitfalls/) -- confirms array ordering bug and auto-save issues
- [SwiftData Issues in macOS 14 and iOS 17 (Michael Tsai)](https://mjtsai.com/blog/2024/06/04/swiftdata-issues-in-macos-14-and-ios-17/) -- additional SwiftData bug reports
- [swiftui-macos-tree-list-demo](https://github.com/shufflingB/swiftui-macos-tree-list-demo) -- DisclosureGroup drag-and-drop pattern
- [Notarization workflow guide](https://tonygo.tech/blog/2023/notarization-for-macos-app-with-notarytool) -- complete notarytool pipeline
- [Import sessions from MobaXterm (Devolutions)](https://forum.devolutions.net/topics/21272/import-sessions-from-mobaxterm) -- community .mxtsessions parsing experience
- [MobaXterm session converter (Python)](https://github.com/ktsouvalis/mobaxterm-sessions) -- reference implementation for .mxtsessions parsing

### Tertiary (LOW confidence)
- Perfect-INIParser (SPM) -- exists but unsuitable for .mxtsessions format; included for reference only
- Tab tearoff via NSWindow.addTabbedWindow -- API exists but integration with SwiftUI WindowGroup needs validation at implementation time

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all Apple-native APIs, well-documented, macOS 14+ target
- Architecture: HIGH -- MVVM + @Observable, JSON persistence, NavigationSplitView are proven patterns
- .mxtsessions format: HIGH -- community reverse engineering is thorough and cross-verified by multiple tools (Royal Apps, Devolutions, Python converter)
- Pitfalls: HIGH -- SwiftData bug confirmed by multiple independent sources; entitlements pitfall well-documented
- Distribution: MEDIUM -- notarytool pipeline well-documented but requires Developer ID certificate (not verified as available)

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable Apple APIs; .mxtsessions format may change with new MobaXterm versions)
