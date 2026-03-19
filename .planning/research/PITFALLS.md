# Domain Pitfalls

**Domain:** macOS native SSH/RDP/VNC session manager with built-in terminal emulator
**Researched:** 2026-03-19
**Confidence:** MEDIUM (based on training data; web search unavailable for verification)

> Note: Web search was unavailable during this research session. All findings are based on well-documented patterns in macOS app development, terminal emulator engineering, and SSH tooling. Confidence is MEDIUM overall -- these are established problem domains, but version-specific details (especially around macOS Sequoia / Tahoe changes) should be verified during implementation.

---

## Critical Pitfalls

Mistakes that cause rewrites, blocked users, or fundamental architecture problems.

### Pitfall 1: App Sandbox Blocks SSH Process Spawning and Key Access

**What goes wrong:** macOS App Sandbox (required for App Store, optional for DMG) severely restricts process spawning. Even without full sandbox, Hardened Runtime (required for notarization) restricts dynamic library loading and certain system calls. SSH key files in `~/.ssh/` may be inaccessible. Spawning `/usr/bin/ssh` as a subprocess can fail or behave unexpectedly under entitlement restrictions.

**Why it happens:** Developers start building with default Xcode project settings that enable App Sandbox, or they later want App Store distribution and discover their architecture is incompatible. Even DMG distribution requires notarization (since macOS Catalina), which requires Hardened Runtime.

**Consequences:** App cannot spawn SSH processes, cannot read SSH keys, cannot access Keychain items. Users get cryptic "Operation not permitted" errors. Worst case: entire process management architecture must be rewritten.

**Prevention:**
- Decide on entitlements from Day 1. For DMG-only distribution: use Hardened Runtime WITHOUT App Sandbox.
- Explicitly configure entitlements: `com.apple.security.network.client` (outbound connections), `com.apple.security.process-start` (if sandboxed), `com.apple.security.files.user-selected.read-write`.
- If NOT sandboxed (recommended for this app): Hardened Runtime with `com.apple.security.cs.allow-unsigned-executable-memory` (may be needed for SwiftTerm's terminal rendering) and `com.apple.security.cs.disable-library-validation` if loading XQuartz libs.
- Test SSH key access, process spawning, and Keychain access under the EXACT entitlement configuration you ship with. Do not develop unsigned and add signing later.

**Detection:** SSH connections fail silently or with permission errors; `ssh` subprocess exits immediately with no output; Keychain prompts never appear or always fail.

**Phase relevance:** Must be resolved in Phase 1 (project scaffold). Wrong entitlements poison everything downstream.

---

### Pitfall 2: PTY Lifecycle Mismanagement -- Zombie Processes and Leaked File Descriptors

**What goes wrong:** Each SSH terminal session requires a pseudo-terminal (PTY). When users close tabs, disconnect, or the app crashes, the PTY and its child SSH process must be cleaned up. Failing to do so creates zombie `ssh` processes, leaked file descriptors, and eventually system resource exhaustion.

**Why it happens:** PTY management is subtle. The child process (SSH) and the PTY master/slave pair have independent lifecycles. Closing the tab's UI does not automatically kill the SSH process. `waitpid()` must be called to reap children. Signal handling (`SIGHUP`, `SIGTERM`) must be explicit. Crash paths skip cleanup entirely.

**Consequences:** Users accumulate zombie SSH processes visible in Activity Monitor. System runs out of PTY devices (macOS has a limit, typically 512). File descriptor leaks cause "Too many open files" errors across the entire app. Orphaned SSH sessions hold server-side resources and can trigger security alerts.

**Prevention:**
- Create a `SessionLifecycleManager` that owns the PTY fd and child PID together as a single unit.
- On tab close: send `SIGHUP` to process group, then `SIGTERM` after 2s timeout, then `SIGKILL` after 5s. Call `waitpid()` with `WNOHANG` in a cleanup loop.
- Use `atexit()` and signal handlers for crash cleanup. Register all active sessions in a cleanup registry.
- Set `FD_CLOEXEC` on all PTY file descriptors so they do not leak to child processes.
- Implement a periodic reaper that checks for orphaned processes (match by PPID).
- SwiftTerm handles some of this internally via its `LocalProcess` class, but you MUST still manage the SSH process lifecycle yourself since SSH sessions are remote processes piped through a local PTY.

**Detection:** Run `ps aux | grep ssh` after closing tabs -- orphaned processes should not remain. Monitor file descriptor count with `lsof -p <pid> | wc -l` during testing.

**Phase relevance:** Core infrastructure, must be right in Phase 1-2 when building the SSH connection layer. Retrofitting cleanup is error-prone.

---

### Pitfall 3: Terminal Emulator ANSI/VT100 Incompatibility

**What goes wrong:** The terminal emulator fails to correctly render output from common tools (vim, tmux, htop, midnight commander). Broken rendering includes: garbled colors, misaligned TUI layouts, broken mouse support, incorrect cursor positioning, missing Unicode/emoji rendering.

**Why it happens:** Terminal emulation requires implementing hundreds of ANSI escape sequences, xterm control codes, and edge cases. SwiftTerm covers most of this, but integration mistakes are common: wrong TERM environment variable, incorrect terminal size reporting, missing `LANG`/`LC_*` environment variables for UTF-8, not forwarding mouse events, not handling terminal resize (`SIGWINCH`) when the SwiftUI view resizes.

**Consequences:** Power users (the target audience) use tmux, vim, and TUI tools daily. Broken rendering makes the app unusable for them -- they will fall back to Terminal.app or iTerm2 immediately.

**Prevention:**
- Set `TERM=xterm-256color` (not `xterm` or `vt100`) in the SSH session environment.
- Set `LANG=en_US.UTF-8` and appropriate `LC_*` variables.
- Forward `SIGWINCH` to the child process when the terminal view resizes. With SwiftTerm, use its `sizeChanged()` API.
- Enable mouse event reporting in SwiftTerm configuration.
- Build a test matrix: verify rendering of vim (with syntax highlighting), tmux (split panes), htop (bar graphs), `man` pages (bold/underline), and midnight commander (box drawing characters).
- Test with servers that have different locales -- a UTF-8 client talking to a LATIN-1 server produces mojibake.

**Detection:** Open tmux with split panes and resize the window -- lines should not garble. Open vim and check that syntax highlighting renders correctly. Try emoji in the terminal (`echo "test"` on a modern server).

**Phase relevance:** Phase 2 (terminal emulator integration). Must be validated before building SFTP or other features on top.

---

### Pitfall 4: macOS Notarization and Code Signing for DMG Distribution

**What goes wrong:** The app builds and runs locally but cannot be distributed. Users who download the DMG see "app is damaged and can't be opened" or Gatekeeper blocks execution entirely. Even after fixing signing, updates break notarization because a new dependency was added without proper signing.

**Why it happens:** Since macOS Catalina (10.15), all distributed apps require:
1. Code signing with a Developer ID certificate (NOT just a development cert)
2. Hardened Runtime enabled
3. Notarization via Apple's notary service
4. Stapling the notarization ticket to the DMG

Many developers skip this during development, then discover at distribution time that their entitlements are incompatible or that embedded frameworks/libraries are unsigned.

**Consequences:** Cannot distribute the app. Coworkers cannot open it. Workarounds like `xattr -cr` are unacceptable for non-technical distribution (though this audience is technical, it is still a bad first impression). If you instruct users to disable Gatekeeper, you are training them to bypass security.

**Prevention:**
- Set up CI-based code signing and notarization from Day 1. Do not defer this.
- Use `xcrun notarytool` (not the deprecated `altool`) for notarization.
- Create a DMG build script that: (1) builds the Release archive, (2) signs with Developer ID, (3) creates DMG with `create-dmg` or `hdiutil`, (4) signs the DMG, (5) submits to notary service, (6) staples the ticket.
- Test every build on a CLEAN macOS install (or a different user account that has never run the unsigned version) -- `xattr` flags persist per-user.
- If embedding XQuartz-related libraries or any third-party frameworks, they ALL must be signed.

**Detection:** Download your own DMG from a web server (not local file copy) on a clean account. If Gatekeeper blocks it, notarization failed.

**Phase relevance:** Set up in Phase 1 (project scaffold / CI). Validate on every release build, not just at the end.

---

### Pitfall 5: SFTP Session Architecture -- Separate vs. Multiplexed Connections

**What goes wrong:** SFTP file browser creates a separate SSH connection for file operations, doubling authentication prompts and connection overhead. Or worse, it shares the terminal's SSH channel and blocks terminal I/O during file transfers. Large file transfers freeze the UI or consume unbounded memory.

**Why it happens:** SFTP runs over SSH, so there are two architectural choices: (A) open a second SSH connection for SFTP, or (B) multiplex over the existing connection using SSH connection multiplexing (`ControlMaster`). Both have tradeoffs that are not obvious until implementation.

**Consequences:**
- Separate connection: user gets double password prompts (unless credentials cached), double key verification, connection storms on servers with rate limiting, and the SFTP session can desync from the terminal session (terminal disconnects but SFTP panel still shows old file listing).
- Shared/multiplexed: terminal freezes during large file transfers, file operations block on terminal activity, complexity of managing SSH channel multiplexing.
- Both: large file transfers (hundreds of MB) cause memory pressure if buffered in-app rather than streamed.

**Prevention:**
- Use SSH `ControlMaster` multiplexing. Set up a Unix domain socket (`ControlPath`) per session. The terminal session is the master; SFTP opens a multiplexed slave connection over the same socket. This avoids re-authentication.
- Stream file transfers in chunks (64KB-256KB) with progress reporting. Never load entire files into memory.
- Run SFTP operations on a background thread/actor. The UI must remain responsive during transfers.
- Handle the case where the master (terminal) disconnects before the SFTP transfer completes -- the transfer must either complete independently or fail gracefully with a clear error.
- Consider using `libssh2` bindings (via Swift package) instead of shelling out to `sftp` command-line tool, for better programmatic control.

**Detection:** Transfer a 500MB file while actively using the terminal. Neither should block the other. Close the terminal tab mid-transfer and verify no crash or hang.

**Phase relevance:** Architecture decision needed in Phase 2-3 (when designing SSH connection layer). Implementation in the SFTP phase, but the multiplexing infrastructure must exist first.

---

## Moderate Pitfalls

### Pitfall 6: XQuartz DISPLAY Variable Management and Per-Tab Isolation

**What goes wrong:** X11 forwarding works for the first SSH session but fails for subsequent ones, or X11 windows from different sessions appear on each other's displays. The DISPLAY variable gets set globally instead of per-session.

**Why it happens:** XQuartz sets `DISPLAY` in the user's environment (typically `:0` or `/tmp/.X11-unix/X0`). But SSH X11 forwarding creates a *remote* DISPLAY (like `localhost:10.0`) that is unique per SSH connection. If the app sets DISPLAY before spawning SSH or shares environment between sessions, X11 forwarding breaks. Additionally, XQuartz may not be running when the SSH session starts.

**Prevention:**
- Do NOT set DISPLAY in the spawned SSH process environment. Let SSH handle X11 forwarding via `-X` or `-Y` flags. SSH sets the remote DISPLAY automatically.
- Detect XQuartz installation by checking for `/opt/X11/bin/xquartz` or `/Applications/Utilities/XQuartz.app`.
- Detect if XQuartz is running via `pgrep -x Xquartz` or checking for the DISPLAY socket. If not running, launch it before starting X11-enabled SSH sessions.
- Each SSH session manages its own X11 forwarding independently -- no shared DISPLAY state.
- Provide clear UI indication of X11 forwarding status per session (enabled/disabled/failed).

**Detection:** Open two SSH sessions with X11 forwarding to different servers. Run `xeyes` on each. Both should display independently. Kill one session -- the other's X11 apps should continue working.

**Phase relevance:** Phase 3-4 (X11 forwarding feature). Must understand XQuartz lifecycle before implementing.

---

### Pitfall 7: SwiftUI Rendering Performance for Terminal Output

**What goes wrong:** The terminal view stutters, drops frames, or becomes unresponsive when commands produce large output (e.g., `cat` a large log file, `find /` output, compiler output). Scrollback buffer grows unbounded and consumes gigabytes of memory.

**Why it happens:** SwiftUI's declarative rendering model is optimized for standard UI, not for a terminal that can receive thousands of lines per second. If each line update triggers a SwiftUI view rerender, performance collapses. SwiftTerm uses AppKit/NSView internally (not SwiftUI), but integrating it via `NSViewRepresentable` introduces a bridging layer that can add overhead if managed incorrectly.

**Prevention:**
- Use SwiftTerm's `TerminalView` (AppKit-based) wrapped in `NSViewRepresentable`. Do NOT try to build a terminal view in pure SwiftUI.
- Cap scrollback buffer size (e.g., 10,000 lines default, configurable). Provide clear UX when buffer is full (oldest lines dropped).
- Ensure the SwiftTerm view handles its own rendering loop -- do not proxy terminal output through SwiftUI state (@State/@Published). The terminal view should read directly from its buffer.
- Profile with Instruments (Time Profiler + Allocations) during a `yes` command stress test (infinite output at maximum speed).
- Batch terminal output processing -- do not re-render on every byte received. SwiftTerm handles this internally, but verify that your I/O read loop feeds data in reasonable chunks (read up to 4KB-8KB at a time from the PTY fd).

**Detection:** Run `yes | head -100000` and verify the UI does not freeze. Run `cat /dev/urandom | base64 | head -c 10M` and check memory usage stays bounded. Resize the terminal during rapid output and verify no crash.

**Phase relevance:** Phase 2 (terminal emulator integration). Performance testing should be part of the terminal milestone acceptance criteria.

---

### Pitfall 8: Keychain Access Patterns and Authentication UX

**What goes wrong:** The app prompts for Keychain access on every SSH connection, or Keychain items created by the app cannot be found later, or the app stores credentials in a way that other apps can read them. Users on corporate Macs hit MDM-enforced Keychain restrictions.

**Why it happens:** macOS Keychain has complex access control:
- Items have an Access Control List (ACL) that specifies which apps can read them.
- If you sign the app with a different certificate (e.g., development vs. distribution), the ACL no longer matches and the item is "lost."
- Keychain prompts ("App wants to access keychain item") appear when ACLs are ambiguous.
- Corporate MDM profiles can restrict Keychain access or disable iCloud Keychain sync.

**Consequences:** Users must re-enter credentials after every app update (if signing identity changes). Constant Keychain permission dialogs erode trust. Credentials stored insecurely are a liability.

**Prevention:**
- Use the Keychain Services API (Security framework), not the legacy SecKeychain API.
- Set `kSecAttrAccessGroup` to your app's team ID + bundle ID to scope items correctly.
- Use `kSecAttrAccessible` = `kSecAttrAccessibleWhenUnlocked` (not `AfterFirstUnlock` or `Always`).
- For the SSH key vault (AES-encrypted local file per PROJECT.md): use `CryptoKit` for AES-GCM encryption with a key derived from a user-provided master password via PBKDF2/Argon2. Store the derived key in Keychain.
- Test the full cycle: store credential -> quit app -> reopen app -> retrieve credential -> update app (re-sign with same cert) -> retrieve credential again.
- Handle Keychain failures gracefully: if access denied, prompt user to re-enter credentials rather than crashing.

**Detection:** After storing a password, sign the app with a different provisioning profile and try to retrieve it. If it fails, your ACL or access group is wrong.

**Phase relevance:** Phase 2-3 (credential management). Keychain identity must match distribution signing identity from Phase 1.

---

### Pitfall 9: RDP/VNC App Detection and Delegation Across macOS Versions

**What goes wrong:** The app assumes Microsoft Remote Desktop or Screen Sharing.app exists at a fixed path and breaks when they are not installed, renamed, or moved in a macOS update. URLs schemes (`vnc://`, `rdp://`) stop working or behave differently across macOS versions.

**Why it happens:** macOS built-in VNC (Screen Sharing) has moved locations across macOS versions. Microsoft Remote Desktop is a separate App Store install and may not be present. The `rdp://` URL scheme support varies. Apple has periodically changed how Screen Sharing integrates with the system.

**Consequences:** RDP/VNC sessions fail to launch. Users get unhelpful "no app to handle this" errors. The app appears broken for a core feature.

**Prevention:**
- For VNC: use `NSWorkspace.shared.open(URL(string: "vnc://host:port")!)` -- this delegates to the system's VNC handler regardless of where Screen Sharing.app lives. Check return value for failure.
- For RDP: first check if Microsoft Remote Desktop is installed via `NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.rdc.macos")`. If not installed, check for the older bundle ID `com.microsoft.rdc.mac`. If neither, show a helpful "Install Microsoft Remote Desktop from the App Store" message with a direct link.
- Never hardcode paths like `/System/Library/CoreServices/Screen Sharing.app` -- use bundle identifiers and URL schemes.
- Provide fallback: if no RDP client is found, offer to copy an RDP connection file (`.rdp`) that the user can open with any client they install.
- Test on the oldest macOS version you support and the newest.

**Detection:** Uninstall Microsoft Remote Desktop and try to open an RDP session. The app should show a clear install prompt, not crash. Test VNC on both Intel and Apple Silicon Macs.

**Phase relevance:** Phase 3 (RDP/VNC integration). Low complexity but high user-facing impact if broken.

---

### Pitfall 10: Session State Persistence and Crash Recovery

**What goes wrong:** The app crashes or is force-quit, and all open sessions are lost. Users must manually reconnect to 10+ servers. Or worse, the session database becomes corrupted after a crash and all saved sessions are lost permanently.

**Why it happens:** Session state (which tabs are open, their connection status, scroll position) is only held in memory. The session database (saved connections with credentials) uses a file format that is not crash-safe (e.g., writing a JSON file that gets truncated during a crash).

**Prevention:**
- Saved sessions (the connection library): use SQLite via GRDB.swift or Core Data with WAL mode. Both are crash-safe. Do NOT use a plain JSON/plist file for the session database -- partial writes corrupt the entire file.
- Active session state (open tabs): persist tab state (host, connection params, NOT passwords) to a separate file on every tab open/close. Use atomic writes (`Data.write(to:options:.atomic)`).
- On app launch: detect if the previous session was a crash (use a "clean shutdown" flag file). If crash detected, offer to reconnect to previously-open sessions.
- Reconnection logic: implement automatic reconnect with exponential backoff for dropped SSH connections. Show clear "Disconnected -- click to reconnect" state in the tab, not a blank terminal.
- Back up the session database periodically (copy to `.backup` before writes).

**Detection:** Force-kill the app (`kill -9`) while 5 sessions are open. Relaunch. The saved session list should be intact. The app should offer to reopen the 5 previously-active sessions.

**Phase relevance:** Database choice in Phase 1. Crash recovery in Phase 4-5 (polish). Reconnection logic in Phase 2-3 (SSH layer).

---

## Minor Pitfalls

### Pitfall 11: Tab Management Memory Leaks

**What goes wrong:** Each closed tab leaks the terminal view, PTY file descriptors, or SSH process handles. After opening and closing 50 tabs, the app uses 2GB+ of RAM.

**Prevention:** Use Instruments Leaks and Allocations to profile a cycle of open-tab, connect, run commands, close-tab repeated 50 times. SwiftTerm's TerminalView must be fully released -- check for retain cycles in closures/delegates. Use weak references in delegate patterns.

**Phase relevance:** Phase 2-3 (continuous testing concern).

---

### Pitfall 12: Keyboard Shortcut Conflicts

**What goes wrong:** Terminal keyboard shortcuts (Ctrl+C, Ctrl+D, Ctrl+Z, Ctrl+A) are intercepted by macOS or SwiftUI menu items instead of being sent to the terminal. Meta/Option key does not send escape sequences as expected.

**Prevention:**
- SwiftTerm handles most keystrokes internally when it has focus, but verify that SwiftUI/AppKit menu items with keyboard shortcuts (Cmd+C for copy, etc.) do not steal Ctrl+key combos.
- Configure Option key behavior: macOS uses Option for special characters (e.g., Option+N for tilde). Terminal apps typically need Option to send ESC+key (Meta key). Provide a preference toggle like iTerm2's "Option sends Meta."
- Test: Ctrl+C should kill a running process in the terminal, not copy text. Ctrl+A should go to beginning of line in bash, not select all.

**Phase relevance:** Phase 2 (terminal integration). Easy to overlook, very annoying for power users.

---

### Pitfall 13: SSH Agent Forwarding and ProxyJump/ProxyCommand Support

**What goes wrong:** Users who rely on SSH agent forwarding (`-A`), jump hosts (`-J`), or custom ProxyCommand configurations find that these do not work because the app constructs SSH commands that do not support these features, or the SSH agent socket is inaccessible.

**Prevention:**
- Allow users to specify arbitrary SSH options per session (free-form field for additional SSH flags).
- Ensure `SSH_AUTH_SOCK` is passed through to the spawned SSH process environment.
- Support `~/.ssh/config` by default -- do not construct SSH commands that override the user's config. Prefer spawning `ssh hostname` and letting the user's SSH config handle the rest, rather than building `-p port -l user -i key` flags that bypass config.
- Test with a bastion/jump host setup: `ssh -J bastion target`.

**Phase relevance:** Phase 2-3 (SSH connection layer). Critical for DevOps users who universally use SSH config and agent forwarding.

---

### Pitfall 14: Drag-and-Drop and Clipboard Integration Pitfalls

**What goes wrong:** Users cannot paste multi-line text into the terminal (each line triggers a command), or drag-and-drop file upload to SFTP does not work because the app does not register as a drag target, or clipboard content from the terminal is plain text when it should preserve formatting.

**Prevention:**
- Implement "bracketed paste mode" in the terminal -- this is an xterm feature where pasted text is wrapped in escape sequences so the shell knows it is a paste (prevents line-by-line execution). SwiftTerm supports this; ensure it is enabled.
- For SFTP drag-and-drop: register the SFTP panel as an `NSView` drop target for file URLs. Handle both Finder drags and inter-app drags.
- Clipboard: copy from terminal should be plain text (standard behavior). Do not try to preserve ANSI colors in clipboard.

**Phase relevance:** Phase 3-4 (SFTP and polish).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Project scaffold / signing | Wrong entitlements block SSH and Keychain (Pitfall 1, 4) | Configure Hardened Runtime + entitlements + notarization pipeline on Day 1 |
| Terminal emulator | ANSI rendering breaks for power users (Pitfall 3, 7, 12) | Build a test matrix: vim, tmux, htop, mc. Performance test with `yes` command |
| SSH connection layer | Zombie processes and leaked PTYs (Pitfall 2) | SessionLifecycleManager with cleanup registry and process reaper |
| SSH connection layer | Ignoring user SSH config (Pitfall 13) | Default to `ssh hostname` respecting `~/.ssh/config`, not manual flag construction |
| Credential management | Keychain items lost after re-signing (Pitfall 8) | Lock down signing identity early; test credential retrieval across app updates |
| SFTP integration | Double auth prompts or blocked terminal (Pitfall 5) | Use SSH ControlMaster multiplexing from the start |
| RDP/VNC delegation | Hardcoded app paths break across macOS versions (Pitfall 9) | Use bundle identifiers and URL schemes, never filesystem paths |
| X11 forwarding | DISPLAY variable conflicts between sessions (Pitfall 6) | Let SSH manage DISPLAY; detect/launch XQuartz before connection |
| Session persistence | Crash corrupts session database (Pitfall 10) | Use SQLite (WAL mode) for session store, not JSON/plist |
| App polish | Memory leaks from tab lifecycle (Pitfall 11) | Profile with Instruments on every milestone |

---

## Sources

- macOS Hardened Runtime documentation (Apple Developer): establishes entitlement requirements for notarized apps
- SwiftTerm GitHub repository (migueldeicaza/SwiftTerm): terminal emulator architecture and known limitations
- macOS Code Signing and Notarization guides (Apple Developer): DMG distribution requirements
- POSIX PTY documentation: pseudo-terminal lifecycle management
- SSH OpenSSH documentation: ControlMaster multiplexing, X11 forwarding, agent forwarding
- macOS Keychain Services documentation (Apple Developer): access control lists and credential storage

*Confidence note: All findings are based on training data (domain knowledge through early 2025). macOS Tahoe (if released) may introduce new sandboxing or signing requirements. Verify against current Apple documentation during implementation.*
