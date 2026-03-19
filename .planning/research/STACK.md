# Technology Stack

**Project:** MobaXterm Mac Alternative
**Researched:** 2026-03-19
**Overall Confidence:** MEDIUM (training data only -- WebSearch/WebFetch/Bash/Context7 were unavailable during research; all versions need verification before adoption)

---

## Recommended Stack

### Core Application Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Swift | 5.9+ | Primary language | Required by project constraints. Swift is the only viable choice for native macOS with modern concurrency (async/await, actors), strong type safety, and direct access to macOS system APIs (Keychain, Process, NSWorkspace). | HIGH |
| SwiftUI | macOS 14+ (Sonoma) | UI framework | Declarative UI with native tab views, split views, sidebar navigation, and sheets -- all core to a session manager. SwiftUI on macOS 14+ is mature enough for production desktop apps. Targeting Sonoma+ gives access to `Observable` macro (replaces `ObservableObject`), improved `NavigationSplitView`, and stable `Table` views. | HIGH |
| AppKit (interop) | macOS 14+ | Terminal hosting, system integration | SwiftTerm provides an `NSView`-based terminal. Use `NSViewRepresentable` to embed in SwiftUI. Also needed for: `NSOpenPanel` (file dialogs), `NSDraggingDestination` (drag-drop for SFTP), menu bar customization, and window-level tab management via `NSWindow.tabbingMode`. | HIGH |
| Xcode | 15+ | IDE and build system | Required for SwiftUI previews, asset catalogs, code signing, and archive/export for DMG. | HIGH |

### Terminal Emulator

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| SwiftTerm | latest main (SPM) | In-app terminal emulator | The only serious pure-Swift terminal emulator library. Created by Miguel de Icaza (Mono/.NET fame). Provides a full VT100/xterm-compatible terminal view as an `NSView` (macOS) or `UIView` (iOS). Supports 256 colors, mouse events, selection, copy/paste, scrollback buffer. Used in production by several macOS SSH clients. Integrates via `NSViewRepresentable` into SwiftUI. | HIGH |

**Why not alternatives:**

| Alternative | Why Not |
|-------------|---------|
| Build custom terminal | VT100/xterm emulation is enormously complex (escape sequences, unicode handling, alternate screen buffer, sixel graphics). Would take months and still be worse than SwiftTerm. |
| WebView + xterm.js | Adds Electron-like overhead, breaks native feel, complicates IPC between Swift and JS. Defeats the purpose of going native. |
| Launch Terminal.app | Project requirement explicitly states terminal must be inside the app, not external. |

**SwiftTerm integration pattern:**

SwiftTerm exposes `LocalProcessTerminalView` (for local shells) and a `TerminalView` base class you can feed data to from any source (SSH channel). For SSH sessions, you create a `TerminalView`, connect its input/output delegates to your SSH channel's data stream, and embed it via `NSViewRepresentable`. This is the standard pattern.

### SSH Library

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| System SSH via `Process` | macOS built-in | SSH connections | **Primary recommendation.** Shell out to the system `ssh` binary (`/usr/bin/ssh`) using Swift's `Process` (formerly `NSTask`). This leverages the user's existing `~/.ssh/config`, known_hosts, SSH agent, ProxyJump chains, and all OpenSSH features without reimplementing anything. The process stdin/stdout/stderr are connected to SwiftTerm's `TerminalView` via pipes. This is exactly how iTerm2, Terminal.app, and most macOS terminal apps work. | HIGH |
| libssh2 (via C interop) | 1.11.x | SFTP file browser, X11 forwarding control | For the SFTP browser panel, you need programmatic SFTP access (list directories, upload, download, stat files). System `sftp` command is too clunky for a GUI file browser. libssh2 provides a proper SFTP API. Import via a Swift C-interop wrapper or SPM package. Also gives programmatic control for X11 forwarding setup if needed. | MEDIUM |

**Why not alternatives:**

| Alternative | Why Not |
|-------------|---------|
| swift-nio-ssh (Apple) | Apple's NIO-SSH is a protocol implementation, not a high-level SSH client. It lacks SFTP support entirely. Building a full SSH client on top of it means implementing key exchange negotiation, channel multiplexing, PTY allocation, and SFTP yourself. Enormous effort for no benefit over system SSH. It is appropriate for building SSH servers, not clients. |
| NMSSH | Objective-C wrapper around libssh2. Mostly unmaintained (last significant update ~2020). If you're going to use libssh2 anyway, better to write a thin Swift wrapper directly than depend on a stale ObjC bridge. |
| Shelling out to `sftp` command | Works for simple transfers but building an interactive file browser (ls, cd, stat, upload, download with progress) on top of a CLI tool's text output is fragile and slow. libssh2's SFTP API is proper programmatic access. |
| Citadel (swift-nio-ssh-based) | Community wrapper around swift-nio-ssh. Adds some convenience but still lacks mature SFTP. Young library, small community. |

**Dual approach rationale:** Use system SSH for terminal sessions (maximum compatibility, zero protocol bugs, supports everything OpenSSH supports) and libssh2 for SFTP (programmatic file operations). This is the same architecture used by Termius and other professional macOS SSH clients.

### RDP Approach

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Microsoft Remote Desktop (system) | App Store version | RDP connections | **Delegate to system app.** The project spec says to leverage macOS system tools for RDP. Microsoft Remote Desktop is free on the Mac App Store and is the standard. Use `NSWorkspace.shared.open(url)` with an `rdp://` URL scheme or generate a `.rdp` file and open it. The app manages sessions by storing RDP connection configs and launching them. | HIGH |
| open(1) + .rdp file | macOS built-in | Launch RDP sessions | Generate a `.rdp` configuration file programmatically (it's a simple INI-like text format), save it to a temp directory, and open it with `NSWorkspace`. This gives control over resolution, gateway, credentials pass-through, etc. | HIGH |

**Why not alternatives:**

| Alternative | Why Not |
|-------------|---------|
| FreeRDP embedded | FreeRDP is a C library that could render RDP inside the app. But it's a massive dependency, complex to build on macOS, and the rendering quality is worse than Microsoft's own client. The project spec explicitly says to delegate to system tools. |
| Build RDP protocol | Insane complexity. RDP is one of the most complex remote desktop protocols. |
| Embed via XPC/window capture | Fragile, breaks with app updates, poor UX. |

**Detection pattern:** At startup, check if Microsoft Remote Desktop is installed via `NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.rdc.macos")`. If missing, show a prompt directing the user to the App Store. Optionally also check for `com.microsoft.rdc.mac` (older bundle ID).

### VNC Approach

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| macOS Screen Sharing | Built-in | VNC connections | **Delegate to system app.** macOS ships with Screen Sharing.app (`/System/Library/CoreServices/Applications/Screen Sharing.app`) which is a full VNC client. Launch it via `vnc://` URL scheme: `NSWorkspace.shared.open(URL(string: "vnc://host:port")!)`. This is the standard approach and matches the project spec. | HIGH |

**Why not alternatives:**

| Alternative | Why Not |
|-------------|---------|
| LibVNCClient embedded | Could render VNC inside the app, but adds a C dependency, needs pixel buffer management, and macOS Screen Sharing is already excellent and free. Not worth the effort for v1. |
| TigerVNC/RealVNC | Third-party apps that users would need to install separately. Screen Sharing is already there. |

### SFTP File Browser

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| libssh2 SFTP API | 1.11.x | Programmatic file operations | Same libssh2 used for SSH gives you `libssh2_sftp_*` functions: opendir, readdir, stat, open, read, write, mkdir, rename, unlink. Wrap in a Swift actor for async operations. | MEDIUM |
| SwiftUI List/Table + NavigationSplitView | macOS 14+ | File browser UI | Render the remote filesystem as a SwiftUI `List` with `DisclosureGroup` for directories. Support drag-and-drop between Finder and the SFTP panel using `Transferable` protocol (macOS 13+). | HIGH |

**SFTP architecture:** Create an `SFTPClient` actor that wraps libssh2 SFTP session. Expose async methods: `listDirectory(_:) -> [RemoteFile]`, `download(_:to:progress:)`, `upload(_:from:progress:)`, `stat(_:) -> FileAttributes`, `mkdir(_:)`, `delete(_:)`. The SwiftUI file browser calls these methods and displays results. Progress is reported via `AsyncStream` for upload/download progress bars.

### X11 Forwarding

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| XQuartz detection | Runtime check | X11 forwarding support | Check for XQuartz at `/opt/X11/bin/xquartz` or via `NSWorkspace` bundle ID `org.xquartz.X11`. If present, add `-X` or `-Y` flag to the SSH `Process` command. If absent, disable the X11 toggle in session config and show an installation guide sheet. | HIGH |
| XQuartz | 2.8.x | X11 server on macOS | The only maintained X11 server for macOS. Users install it separately (project spec: keep DMG small). X11 forwarding "just works" with system SSH + XQuartz installed -- no special code needed beyond passing `-X` to ssh. | HIGH |

### Credential Management

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Security.framework (Keychain) | macOS built-in | Password storage | Use `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete` from the Security framework. Store passwords as `kSecClassGenericPassword` items with service = app bundle ID, account = "ssh://user@host:port". This is the macOS-native way to store credentials securely. Keychain items survive app updates and are protected by the user's login password. | HIGH |
| CryptoKit | macOS built-in | SSH key vault encryption | Use `CryptoKit.AES.GCM` for encrypting the SSH key vault file. Derive the encryption key from user's master password via `HKDF` or from Keychain-stored symmetric key. AES-256-GCM provides authenticated encryption (integrity + confidentiality). | HIGH |
| Swift Keychain wrapper | Custom, thin | Ergonomic Keychain access | Write a small `KeychainManager` actor (~100 lines) that wraps the verbose `SecItem*` C API into clean Swift async methods: `save(password:for:)`, `get(for:) -> String?`, `delete(for:)`. Avoid third-party Keychain wrappers (KeychainAccess, etc.) -- they add dependencies for trivial code. | HIGH |

**Key vault design:** SSH private keys are stored in a single encrypted file at `~/Library/Application Support/MobaAlt/keyvault.encrypted`. The file is a JSON dictionary of `{keyName: keyData}` encrypted with AES-256-GCM. The encryption key is derived from a master password (via HKDF) and the master password hash is stored in Keychain. On app launch, the user unlocks the vault once. Keys are held in memory only while the app is running.

### Data Persistence

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| SwiftData | macOS 14+ (Sonoma) | Session/folder storage | SwiftData is Apple's modern persistence framework (successor to Core Data). Use `@Model` classes for `Session`, `Folder`, `SessionGroup`. Provides automatic CloudKit sync potential for future, but for v1 it's local-only SQLite under the hood. Simpler than Core Data, works natively with SwiftUI via `@Query`. | MEDIUM |
| JSON files (fallback) | Built-in | Alternative persistence | If SwiftData proves too opinionated, fall back to Codable structs serialized to JSON in `~/Library/Application Support/MobaAlt/sessions.json`. Simpler, fully transparent, easy to debug. For a session manager with likely <1000 sessions, JSON is perfectly fine. | HIGH |

**Recommendation:** Start with SwiftData for the clean SwiftUI integration. If it causes friction (migration headaches, modeling constraints), pivot to JSON files. The data model is simple enough that either works.

### Networking Foundation

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Swift Concurrency | Swift 5.9+ | Async operations | Use `async/await`, `Task`, `AsyncStream`, and `Actor` for all networking, SSH operations, and SFTP transfers. No need for Combine or callback-based patterns. Actors protect shared state (active sessions, credential cache). | HIGH |
| Foundation.Process | macOS built-in | SSH process management | `Process` class manages the lifecycle of SSH subprocesses. Set up stdin/stdout/stderr `Pipe` objects, connect to SwiftTerm, handle termination notifications. | HIGH |

### Build and Distribution

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| create-dmg | latest (npm/brew) | DMG packaging | CLI tool that creates styled DMG installers with background image, icon positioning, and symlink to /Applications. Simple shell script, widely used. Run as post-build step. | HIGH |
| Xcode Archive + Export | Xcode 15+ | App signing and archival | Use `xcodebuild archive` then `xcodebuild -exportArchive` for reproducible builds. Sign with Developer ID for Gatekeeper (or leave unsigned for internal distribution with `xattr -cr` instructions). | HIGH |
| SwiftLint | 0.54+ | Code quality | Catches common Swift anti-patterns. Runs as Xcode build phase or pre-commit hook. | MEDIUM |
| SwiftFormat | 0.53+ | Code formatting | Consistent formatting across the codebase. Run on save or pre-commit. | MEDIUM |

**DMG distribution note:** For internal team distribution without notarization, recipients will need to right-click > Open or run `xattr -cr MobaAlt.app` to bypass Gatekeeper. Document this in the README. For broader distribution later, notarize with `xcrun notarytool submit`.

### Testing

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| XCTest | Built-in | Unit and integration tests | Standard Swift testing framework. Test the `KeychainManager`, `SFTPClient`, session CRUD, and model layer. | HIGH |
| Swift Testing | Swift 5.9+ | Modern test framework | Apple's newer testing framework with `@Test` macro, `#expect`, parameterized tests. Use alongside or instead of XCTest for new test code. | MEDIUM |
| ViewInspector | latest | SwiftUI view testing | Third-party library for inspecting SwiftUI view hierarchies in tests. Useful for testing session list, folder tree, toolbar state. | LOW |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| UI Framework | SwiftUI + AppKit interop | Pure AppKit | SwiftUI is faster to build with, declarative, and sufficient for this app. AppKit interop covers gaps (terminal view hosting, advanced window management). Pure AppKit means more boilerplate for the same result. |
| UI Framework | SwiftUI + AppKit interop | Electron | Defeats the purpose. 200MB+ bundle, no native feel, poor performance, no direct Keychain/Process access. |
| SSH | System SSH via Process | swift-nio-ssh | NIO-SSH lacks SFTP, requires building full client from protocol primitives. System SSH gives every OpenSSH feature for free. |
| SSH | System SSH via Process | Paramiko (Python) | Wrong language. Would need Python runtime bundled or bridged. |
| SFTP | libssh2 | System sftp command | CLI output parsing is fragile. libssh2 gives proper programmatic API for file operations. |
| Terminal | SwiftTerm | xterm.js in WebView | Breaks native feel, adds web runtime, complicates IPC. |
| Persistence | SwiftData | Core Data | SwiftData is the modern replacement with simpler API. Core Data still works but more verbose. |
| Persistence | SwiftData | SQLite directly | Too low-level for the simple data model. SwiftData wraps SQLite anyway. |
| Keychain | Security.framework direct | KeychainAccess (kishikawakatsumi) | Adds a dependency for ~100 lines of wrapper code. Security framework API is verbose but straightforward. |
| Crypto | CryptoKit | OpenSSL/LibreSSL | CryptoKit is Apple's native crypto library, no need for external C dependencies. |
| RDP | Delegate to MS Remote Desktop | FreeRDP embedded | Massive C dependency, complex macOS build, worse quality than MS client. |

---

## Version Compatibility Matrix

| Component | Minimum macOS | Notes |
|-----------|---------------|-------|
| SwiftUI NavigationSplitView | macOS 13 | Core navigation pattern |
| SwiftUI Observable macro | macOS 14 | Replaces ObservableObject, much cleaner |
| SwiftData | macOS 14 | Modern persistence |
| CryptoKit AES.GCM | macOS 10.15 | Available since Catalina |
| Security.framework | All macOS | Always available |
| Transferable (drag-drop) | macOS 13 | For SFTP drag-drop |

**Target: macOS 14 (Sonoma) minimum.** This gives access to all modern APIs. As of early 2026, Sonoma+ covers the vast majority of Macs in IT/DevOps environments (these teams keep machines updated).

---

## Project Structure

```
MobaAlt/
  MobaAltApp.swift              # App entry point, WindowGroup
  Models/
    Session.swift                # SwiftData @Model: SSH/RDP/VNC session
    Folder.swift                 # SwiftData @Model: folder hierarchy
    Credential.swift             # Credential metadata (not the secret)
  Views/
    Sidebar/
      SessionListView.swift      # Folder tree + session list
      SessionRowView.swift       # Single session row
    Terminal/
      TerminalTabView.swift      # SwiftTerm NSViewRepresentable wrapper
      TerminalSessionManager.swift # Manages Process lifecycle
    SFTP/
      SFTPBrowserView.swift      # Remote file browser panel
      SFTPTransferView.swift     # Upload/download progress
    Sessions/
      SessionEditorView.swift    # Create/edit session form
      RDPLauncherView.swift      # RDP session config + launch
      VNCLauncherView.swift      # VNC session config + launch
    Settings/
      SettingsView.swift         # App preferences
      KeyVaultView.swift         # SSH key management
  Services/
    SSHService.swift             # Process-based SSH management
    SFTPClient.swift             # libssh2 SFTP wrapper (actor)
    KeychainManager.swift        # Security.framework wrapper (actor)
    KeyVaultManager.swift        # AES-encrypted key storage (actor)
    XQuartzDetector.swift        # XQuartz presence detection
    RDPLauncher.swift            # .rdp file generation + launch
    VNCLauncher.swift            # vnc:// URL scheme launch
  Utilities/
    ProcessPipe+SwiftTerm.swift  # Connects Process pipes to TerminalView
```

---

## Installation / Setup

```bash
# Prerequisites
# - Xcode 15+ with Command Line Tools
# - macOS 14 (Sonoma) or later

# Clone and open
git clone <repo-url>
cd moba_mac_alternative
open MobaAlt.xcodeproj

# Dependencies are managed via Swift Package Manager (SPM)
# Xcode resolves them automatically on first open.

# SPM Dependencies:
# - SwiftTerm: https://github.com/migueldeicaza/SwiftTerm (terminal emulator)
# - libssh2 (via C system library or SPM wrapper for SFTP)

# For libssh2 on macOS:
brew install libssh2

# Build and run
# Cmd+R in Xcode, or:
xcodebuild -scheme MobaAlt -configuration Debug build

# Create DMG for distribution
# (after archiving in Xcode)
brew install create-dmg
create-dmg \
  --volname "MobaAlt" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MobaAlt.app" 150 190 \
  --app-drop-link 450 190 \
  "MobaAlt.dmg" \
  "build/MobaAlt.app"
```

---

## Sources and Confidence

| Claim | Source | Confidence |
|-------|--------|------------|
| SwiftTerm is the standard Swift terminal emulator | Training data (migueldeicaza/SwiftTerm on GitHub, widely referenced) | HIGH |
| System SSH via Process is how macOS terminal apps work | Training data (iTerm2 architecture, Terminal.app behavior) | HIGH |
| swift-nio-ssh lacks SFTP | Training data (Apple's repo README states protocol-level only) | MEDIUM -- verify with current repo |
| libssh2 provides SFTP API | Training data (libssh2 docs, widely used) | HIGH |
| Security.framework Keychain API | Apple documentation (stable, unchanged for years) | HIGH |
| CryptoKit AES.GCM availability | Apple documentation | HIGH |
| SwiftData macOS 14+ | Apple WWDC23 announcement | HIGH |
| create-dmg for DMG packaging | Training data (widely used OSS tool) | HIGH |
| Microsoft Remote Desktop bundle ID | Training data | MEDIUM -- verify current bundle ID |
| Screen Sharing.app path and vnc:// URL scheme | Training data (long-standing macOS feature) | HIGH |
| XQuartz path /opt/X11 | Training data (standard XQuartz install path) | HIGH |
| SwiftTerm version numbers | NOT VERIFIED -- used "latest main" instead of pinning | LOW |
| libssh2 version 1.11.x | NOT VERIFIED -- verify current release | LOW |
| SwiftLint/SwiftFormat versions | NOT VERIFIED -- verify current releases | LOW |

**Important:** All version numbers marked LOW confidence should be verified against GitHub releases before adding to Package.swift or Brewfile. WebSearch and WebFetch were unavailable during this research session.
