# Project Research Summary

**Project:** MobaXterm Mac Alternative
**Domain:** Native macOS remote session manager (SSH/RDP/VNC with embedded terminal)
**Researched:** 2026-03-19
**Confidence:** MEDIUM (all research based on training data; web search unavailable for verification)

## Executive Summary

This project fills a genuine gap in the macOS ecosystem: no single native app combines SSH terminal emulation, SFTP file browsing, RDP session management, VNC session management, and X11 forwarding the way MobaXterm does on Windows. The recommended approach is a Swift/SwiftUI application targeting macOS 14 (Sonoma) minimum, using SwiftTerm for terminal emulation, the system `/usr/bin/ssh` binary for SSH connections, libssh2 for SFTP file operations, and macOS URL scheme delegation for RDP/VNC. This stack mirrors how production macOS SSH clients (iTerm2, Termius) are built and avoids reinventing complex protocol implementations.

The recommended architecture is MVVM with Apple's `@Observable` framework, organized around a sidebar session browser, a tabbed main content area, and a layered service model (ConnectionManager, SessionStore, CredentialStore). The most important architectural decision is delegating RDP/VNC to system apps rather than embedding protocol implementations — this keeps scope realistic for v1. For SSH, using the system binary rather than a Swift SSH library gives every OpenSSH feature (agent forwarding, ProxyJump, `~/.ssh/config`, known_hosts) for free.

The two biggest risks are (1) macOS code signing and entitlement configuration — wrong settings at project setup block SSH process spawning and Keychain access, poisoning the entire architecture — and (2) PTY lifecycle management, where failing to properly clean up SSH child processes and file descriptors causes resource exhaustion. Both must be addressed in the first phase, not retrofitted later. Secondary risks include SFTP session architecture (avoid double authentication by using SSH ControlMaster multiplexing) and terminal emulator compatibility (tmux, vim, htop rendering must be validated early because power users will reject the app immediately if these break).

## Key Findings

### Recommended Stack

The stack centers on Swift 5.9+ with SwiftUI (macOS 14 target) for all UI, AppKit interop via `NSViewRepresentable` for the terminal view, and a service layer of Swift actors for concurrency safety. The key dependency is SwiftTerm — the only mature pure-Swift terminal emulator — which handles VT100/xterm emulation as an AppKit `NSView`. All other protocol complexity is either delegated (RDP/VNC to system apps) or proxied through system tools (SSH via `/usr/bin/ssh`). Data persistence uses JSON files with atomic writes in `~/Library/Application Support/MobaAlt/` for v1 (SwiftData is available but adds migration risk). Credentials are split: passwords in macOS Keychain via Security.framework, SSH private keys in an AES-256-GCM encrypted vault file. DMG distribution via `create-dmg` with Hardened Runtime enabled and no App Sandbox.

**Core technologies:**
- **Swift 5.9+ / SwiftUI macOS 14:** Primary language and UI framework — native macOS, modern concurrency (async/await, actors), `@Observable` macro, required by project constraints
- **SwiftTerm (SPM):** Terminal emulation — the only production-quality Swift terminal library; handles VT100/xterm, 256 colors, mouse, scrollback
- **System `/usr/bin/ssh` via Foundation.Process:** SSH connections — inherits user's `~/.ssh/config`, SSH agent, ProxyJump, known_hosts; zero protocol code required
- **libssh2 (via Homebrew/C interop):** SFTP file operations — programmatic SFTP API for the file browser panel; system `sftp` CLI is too fragile for a GUI
- **Security.framework (Keychain) + CryptoKit (AES-GCM):** Credential storage — macOS-native password storage and key vault encryption
- **NSWorkspace URL schemes:** RDP (`rdp://` + .rdp files) and VNC (`vnc://`) delegation to system apps
- **JSON files + atomic writes + Swift actors:** Session persistence — crash-safe, zero dependencies, sufficient for v1 scale

### Expected Features

Full details in `.planning/research/FEATURES.md`.

**Must have (table stakes) — Phase 1-2:**
- Saved sessions with name, host, port, username, auth method, organized in folders
- SSH connections in embedded terminal (SwiftTerm, tabbed interface)
- Credential management: macOS Keychain for passwords, SSH key selection per session
- Basic terminal: tabs, scrollback, search, copy/paste, color themes, font selection
- Quick connect (ad-hoc SSH without saving)
- SFTP browser panel auto-opening alongside SSH session (MobaXterm signature feature)
- Port forwarding UI (local/remote/dynamic)
- Jump host / bastion support (ProxyJump)
- RDP and VNC session management (save config + launch via system apps)
- X11 forwarding toggle with XQuartz detection
- Session search/filter, import/export (JSON)

**Should have (competitive differentiators) — Phase 3:**
- Split panes (horizontal and vertical)
- SSH config auto-import from `~/.ssh/config`
- MobaXterm `.mxtsessions` import (zero-friction team migration)
- Command snippets library
- Multi-exec / broadcast input to multiple sessions
- Visual SSH tunnel manager
- Command palette (Cmd+K fuzzy search)
- Session tagging and smart folders
- Local terminal tab (no SSH)

**Defer (v2+):**
- Embedded RDP/VNC viewer (requires FreeRDP/libvnc — very high complexity)
- Plugin/extension system
- Cloud session sync
- Serial/Telnet connections

### Architecture Approach

The app uses MVVM with `@Observable` (not TCA — overkill for this scope) in a single-window NavigationSplitView layout: sidebar (session browser with folder tree) + main content area (tab container). Tabs are polymorphic — SSH tabs show SwiftTerm + SFTP split view, RDP/VNC tabs show status + launch UI. A central `TabManager` owns all tabs via a `TabItem` enum-dispatched model. Services (`SessionStore`, `ConnectionManager`, `CredentialStore`) are Swift actors injected via environment. The `SessionDefinition` model is protocol-agnostic with a `ConnectionProtocol` enum (`ssh`, `rdp`, `vnc`) — credentials are referenced by UUID only, never embedded in session data.

**Major components:**
1. **AppShell** — NavigationSplitView window, menu bar, tab container hosting
2. **SessionBrowser** — sidebar folder tree, session list, search/filter, session CRUD
3. **TabManager** — open/close/switch/reorder tabs, connection state per tab, tab persistence
4. **SSHConnection + TerminalViewWrapper** — Process lifecycle, PTY management, SwiftTerm NSViewRepresentable bridging
5. **SFTPClient (actor)** — libssh2 SFTP session over ControlMaster-multiplexed SSH connection
6. **CredentialStore** — KeychainProvider (passwords) + EncryptedVaultProvider (SSH keys)
7. **RDPLauncher / VNCLauncher** — NSWorkspace URL scheme and .rdp file generation
8. **XQuartzDetector** — installation check, DISPLAY variable management, launch before X11 sessions

### Critical Pitfalls

Full details in `.planning/research/PITFALLS.md`.

1. **App Sandbox / entitlement misconfiguration** — Configure Hardened Runtime WITHOUT App Sandbox on Day 1; test SSH process spawning and Keychain access under exact ship entitlements before writing any other code. Wrong entitlements cause cryptic failures that require architecture rewrites.

2. **PTY zombie processes and file descriptor leaks** — Build a `SessionLifecycleManager` from the start that owns PTY fd and child PID together, sends SIGHUP/SIGTERM/SIGKILL in sequence on tab close, and calls `waitpid()`. Register all sessions in a cleanup registry for crash paths. Verify with `ps aux | grep ssh` after closing tabs.

3. **Terminal ANSI/VT100 incompatibility** — Set `TERM=xterm-256color` and `LANG=en_US.UTF-8`; forward `SIGWINCH` on resize; build a test matrix (vim syntax highlighting, tmux splits, htop bar graphs, box-drawing characters) as milestone acceptance criteria for Phase 2.

4. **SFTP double authentication / blocked terminal** — Use SSH ControlMaster multiplexing (`ControlPath` Unix socket per session) so the SFTP channel rides over the existing terminal connection. Stream file transfers in chunks; never buffer entire files in memory. This architecture decision must be made in Phase 2 before SFTP implementation.

5. **Notarization and DMG distribution** — Set up the signing + notarization CI pipeline (`xcrun notarytool`) in Phase 1, not at release time. Test on a clean macOS user account downloading from a web server — local file copies bypass Gatekeeper.

6. **Session database crash corruption** — Use atomic writes (`Data.write(to:options:.atomic)`) and keep a `.backup` copy before writes. Do NOT use a plain JSON write for the session library — it can be truncated on crash. The session database is the single most critical data the app owns.

## Implications for Roadmap

Based on combined research, the dependency chain is clear and drives a 6-phase structure. Each phase produces a usable, testable increment.

### Phase 1: Project Foundation and Signing Infrastructure
**Rationale:** Entitlement configuration (Hardened Runtime, no App Sandbox) and code signing must be correct before any SSH process spawning or Keychain access is written. Wrong settings poison everything downstream with silent failures that are very hard to diagnose late. Session model and persistence are the data foundation every other phase depends on.
**Delivers:** Runnable app that creates, organizes, and persists sessions (no network connections). Signed and notarizable build pipeline.
**Addresses:** Session CRUD, folder hierarchy, session search, crash-safe persistence
**Avoids:** Pitfall 1 (entitlements), Pitfall 4 (notarization), Pitfall 10 (session database corruption)
**Stack:** SwiftUI NavigationSplitView, JSON persistence with atomic writes, Security.framework setup, Xcode Hardened Runtime configuration

### Phase 2: SSH Terminal Core
**Rationale:** SSH terminal is the highest-value and highest-risk feature. SwiftTerm integration determines the entire product's perception — power users will leave immediately if vim/tmux/htop render incorrectly. Validating this before building dependent features (SFTP, port forwarding, X11) avoids compounding risk. The ControlMaster multiplexing architecture for SFTP must also be established here.
**Delivers:** Working SSH terminal with tabbed sessions, correct ANSI terminal emulation (vim/tmux/htop tested), PTY lifecycle management, ControlMaster socket infrastructure.
**Addresses:** SSH connection, terminal emulator table stakes, tabbed interface, quick connect, port forwarding flags, agent forwarding, ProxyJump
**Avoids:** Pitfall 2 (PTY zombies), Pitfall 3 (ANSI rendering), Pitfall 5 (ControlMaster for SFTP), Pitfall 7 (terminal performance), Pitfall 12 (keyboard shortcuts), Pitfall 13 (SSH config respect)
**Stack:** SwiftTerm (NSViewRepresentable), Foundation.Process, SSH ControlMaster multiplexing

### Phase 3: Credentials and Security
**Rationale:** SFTP needs credentials; separating this into its own phase ensures the credential layer is solid before it is shared across features. Critically, Keychain identity must be locked to the distribution signing certificate now — if the signing identity changes later, all stored credentials become inaccessible.
**Delivers:** Secure credential management: Keychain passwords + AES-GCM SSH key vault with master password. Credentials used in SSH connections from Phase 2.
**Addresses:** Keychain integration, SSH key vault, master password, per-session credential assignment, SSH agent integration
**Avoids:** Pitfall 8 (Keychain ACL and signing identity mismatch)
**Stack:** Security.framework (Keychain Services), CryptoKit (AES-256-GCM), PBKDF2 key derivation

### Phase 4: SFTP Browser
**Rationale:** The SFTP panel is MobaXterm's signature feature and the primary differentiator over iTerm2. It depends on SSH (Phase 2) and credentials (Phase 3). The ControlMaster multiplexing infrastructure from Phase 2 must already exist — SFTP must not create a second independent SSH connection.
**Delivers:** Side-panel SFTP file browser alongside terminal, drag-and-drop upload/download, progress indicators, remote file editing workflow.
**Addresses:** SFTP browser (all table stakes features including auto-open on SSH connect)
**Avoids:** Pitfall 5 (SFTP double auth / blocked terminal), Pitfall 14 (drag-and-drop integration)
**Stack:** libssh2 SFTP API (Swift actor wrapper), SwiftUI HSplitView, Transferable protocol for drag-drop

### Phase 5: RDP, VNC, and X11 Forwarding
**Rationale:** These are lower-complexity integrations (URL scheme launchers) that depend on the session model and tab infrastructure being solid. X11 forwarding is an SSH session flag requiring the Phase 2 connection layer. These complete MobaXterm feature parity.
**Delivers:** RDP and VNC sessions (save config + launch via system apps with graceful missing-app handling), X11 forwarding toggle with XQuartz detection and launch guidance.
**Addresses:** RDP/VNC session management, X11 forwarding, XQuartz detection and install guide
**Avoids:** Pitfall 6 (DISPLAY variable conflicts per session), Pitfall 9 (hardcoded app paths breaking across macOS versions)
**Stack:** NSWorkspace URL schemes, .rdp file generation, XQuartzDetector, bundle ID detection

### Phase 6: Polish and Distribution
**Rationale:** All features exist; now make the app feel native and distributable. Port forwarding UI, split panes, SSH config import, and keyboard shortcuts complete the experience. DMG packaging and notarization validation complete the release pipeline. Memory leak profiling ensures the app is production-quality.
**Delivers:** Distributable notarized DMG with full feature set, polished UX (split panes, session import/export, keyboard shortcuts, settings).
**Addresses:** Port forwarding UI, jump host configuration, split panes, session import/export, session search/filter, tab reordering, keyboard shortcuts, app settings
**Avoids:** Pitfall 11 (tab memory leaks — Instruments profiling required), Pitfall 4 (notarization validated on clean machine)
**Stack:** create-dmg, xcrun notarytool, SwiftLint/SwiftFormat

### Phase Ordering Rationale

- Phase 1 before everything: `SessionDefinition`, entitlements, and signing are the foundation. No SSH process can be reliably tested without correct Hardened Runtime configuration.
- Phase 2 before Phases 3-5: Validate the terminal (most complex and riskiest component) independently before adding credential complexity. ControlMaster architecture established here avoids a later SFTP redesign.
- Phase 3 before Phase 4: SFTP shares the credential layer; building credentials before SFTP avoids duplication and ensures the vault is tested before it guards two features. Keychain signing identity is locked here.
- Phase 4 before Phase 5: SFTP is the core product differentiator. RDP/VNC (URL launchers) are lower-complexity and can wait.
- Phase 6 last: Polish and distribution always follow feature completeness. Memory profiling requires a full app to profile against.

### Research Flags

Phases needing deeper research during planning:
- **Phase 2 (SSH Terminal):** SwiftTerm API details should be verified against current GitHub main branch — training data is MEDIUM confidence on specific API surface (especially the `TerminalDelegate` and `TerminalView` vs. `LocalProcessTerminalView` distinction for remote SSH). Verify ControlMaster socket approach with system `ssh` on current macOS.
- **Phase 3 (Credentials):** Verify CryptoKit PBKDF2 API on macOS 14; confirm Keychain `kSecAttrAccessGroup` scoping for non-sandboxed (Hardened Runtime only) apps.
- **Phase 4 (SFTP):** libssh2 Swift integration approach needs a current dependency survey — the best-maintained SPM wrapper or C interop path may have changed since training data cutoff.

Phases with well-documented standard patterns (skip research-phase):
- **Phase 1 (Foundation):** Session model + JSON persistence + NavigationSplitView are thoroughly documented Apple patterns.
- **Phase 5 (RDP/VNC/X11):** NSWorkspace URL scheme delegation and bundle ID detection are stable, long-standing macOS patterns.
- **Phase 6 (Distribution):** create-dmg + xcrun notarytool pipeline is industry standard with extensive documentation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Core technology choices (Swift, SwiftUI, SwiftTerm, system SSH) are HIGH confidence. Specific package versions for SwiftTerm, libssh2 SPM wrappers, and tooling are LOW — verify against current releases before adoption. |
| Features | MEDIUM | MobaXterm and competitor feature sets are stable and well-documented. Competitive intelligence based on training data through mid-2025. Feature priorities are well-reasoned from project constraints. |
| Architecture | MEDIUM-HIGH | MVVM + @Observable, NSViewRepresentable, NavigationSplitView, and Foundation.Process patterns are HIGH confidence from core Apple documentation. SFTP ControlMaster multiplexing approach is MEDIUM — established pattern but implementation details need validation against current macOS. |
| Pitfalls | MEDIUM | All pitfalls are from well-documented problem domains (macOS signing, PTY management, terminal emulation, Keychain ACLs). Version-specific behavior on macOS Sequoia or later may differ. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **SwiftTerm current API:** The exact `TerminalDelegate` API surface, `LocalProcessTerminalView` vs. `TerminalView` usage for remote SSH, and any breaking changes since WWDC 2024 should be verified at Phase 2 kickoff by reading the current SwiftTerm README and example projects.
- **libssh2 SPM availability:** Evaluate at Phase 4 whether to use `brew install libssh2` + C interop, an available SPM wrapper, or shell out to `/usr/bin/sftp` for v1 simplicity. The best-maintained approach may have shifted.
- **macOS Sequoia changes:** Any macOS 15 Sequoia changes to Hardened Runtime requirements, SSH binary behavior, or Screen Sharing URL scheme handling should be verified before Phase 2 and Phase 5 respectively.
- **SwiftData vs. JSON decision:** STACK.md recommends starting with SwiftData but notes migration risk. Decide at Phase 1 kickoff and commit — do not switch mid-project. The JSON + atomic writes path is lower-risk for v1.
- **Microsoft Remote Desktop bundle ID:** Verify `com.microsoft.rdc.macos` vs. `com.microsoft.rdc.mac` on a live macOS install before Phase 5.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: Security.framework Keychain Services, CryptoKit, Foundation.Process, NSViewRepresentable, NavigationSplitView, @Observable — training data from stable Apple APIs
- Apple Developer Documentation: Hardened Runtime entitlements, code signing, notarization requirements
- SwiftTerm (migueldeicaza/SwiftTerm): terminal emulator architecture — training data, widely referenced in macOS SSH client development

### Secondary (MEDIUM confidence)
- MobaXterm, Royal TSX, Termius, SecureCRT, iTerm2 feature sets — training data knowledge of mature, stable products
- SSH OpenSSH documentation: ControlMaster multiplexing, X11 forwarding, agent forwarding — well-documented stable standard
- macOS URL scheme handling (vnc://, rdp://) — training data, long-standing macOS feature
- POSIX PTY documentation: pseudo-terminal lifecycle management — stable POSIX standard

### Tertiary (LOW confidence — needs verification)
- SwiftTerm specific API surface and current version — verify against GitHub main branch before implementation
- libssh2 Swift SPM wrapper availability and maintenance status — needs current dependency survey
- Microsoft Remote Desktop current bundle ID — verify on a live macOS install
- SwiftLint/SwiftFormat current version numbers — verify against GitHub releases
- macOS Sequoia (15.x) specific behavioral changes — verify against current Apple release notes

---
*Research completed: 2026-03-19*
*Ready for roadmap: yes*
