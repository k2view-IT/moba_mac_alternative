# Phase 2: SSH Terminal Sessions - Research

**Researched:** 2026-03-20
**Domain:** SSH process management, PTY, SwiftTerm terminal emulation, tab UI, Keychain credential storage, SSH key management
**Confidence:** MEDIUM-HIGH (SwiftTerm API verified via official GitHub; PTY approach verified via Swift forums + SwiftTerm source; Keychain patterns are stable Apple APIs)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SSH-01 | User can connect to an SSH host and get a terminal session in a new tab | LocalProcessTerminalView.startProcess() with /usr/bin/ssh, TabManager architecture |
| SSH-02 | SSH sessions support both password and SSH key authentication | Keychain for passwords, encrypted vault for keys, SSHConfig.authMethod already modeled |
| SSH-03 | SSH respects the user's existing ~/.ssh/config and known_hosts files | Foundation.Process inherits user environment; pass hostname only, let OpenSSH read config |
| SSH-04 | User can enable SSH agent forwarding per session | -A flag to ssh process; SSH_AUTH_SOCK inherited from parent environment |
| SSH-05 | User can configure port forwarding rules per session (local, remote, dynamic) | -L/-R/-D flags to ssh process; SSHConfig needs portForwards array |
| SSH-06 | User can view and manage active port forwarding tunnels while connected | Runtime state in SSHConnection; list active -L/-R/-D tunnels from session config |
| SSH-07 | User can generate new SSH key pairs from within the app | Shell out to /usr/bin/ssh-keygen -t ed25519; store private key in AES-GCM vault |
| TERM-01 | Terminal emulator runs inside the app in a tab (no external Terminal.app) | LocalProcessTerminalView wrapped in NSViewRepresentable |
| TERM-02 | Multiple sessions open simultaneously in tabs with easy switching | TabManager + custom SwiftUI tab bar |
| TERM-03 | Terminal supports full color output, scrollback buffer, resize, and ANSI sequences | SwiftTerm v1.12.0; SIGWINCH via sizeChanged delegate; TERM=xterm-256color |
| TERM-04 | Terminal session output can be automatically logged to a file per session | TerminalViewDelegate.dataReceived forwarded to FileHandle writer |
| TERM-05 | User can save reusable command snippets and execute them in the active session | Snippet model + send to LocalProcessTerminalView |
| CRED-01 | SSH and RDP/VNC passwords are stored securely in macOS Keychain | Security.framework SecItemAdd/SecItemCopyMatching |
| CRED-02 | SSH private keys are stored in an AES-GCM encrypted local vault file | CryptoKit.AES.GCM; vault at ~/Library/Application Support/MobaAlt/keyvault.enc |
| CRED-03 | User can unlock the SSH key vault with a master password | PBKDF2/HKDF key derivation; vault actor holds decrypted keys in memory |
| CRED-04 | User can add, view, and remove stored credentials per session | KeyVaultView + KeychainManager actor CRUD |
</phase_requirements>

---

## Summary

Phase 2 builds the core connection layer on top of Phase 1's session management foundation. The central challenge is wiring three subsystems together: (1) SwiftTerm's terminal view, (2) Foundation.Process spawning `/usr/bin/ssh` with a PTY, and (3) a tab management UI. The good news is that SwiftTerm's `LocalProcessTerminalView` already solves the PTY problem — it handles `openpty()`, process lifecycle, and SIGWINCH forwarding internally. The correct approach is to use `LocalProcessTerminalView.startProcess(executable: "/usr/bin/ssh", args: [...])` rather than manually managing PTY file descriptors with `Foundation.Process`.

Credentials are merged into this phase. The design separates passwords (Keychain via `Security.framework`) from SSH private keys (AES-256-GCM encrypted vault file). The vault is unlocked once per app session with a master password; decrypted key material is held only in memory. SSH key generation should shell out to `/usr/bin/ssh-keygen -t ed25519` rather than using `SecKeyCreateRandomKey` — Apple's Security framework cannot produce OpenSSH-compatible key formats (especially openssh-key-v1 format) without substantial additional work.

The tab UI should be a custom SwiftUI horizontal tab bar (not `NSTabView` or `SwiftUI.TabView`), since neither offers the scrollable, closable, chrome-style tabs that a terminal manager needs. A custom implementation built with `ScrollView` + `HStack` is the standard approach for this.

**Primary recommendation:** Use `LocalProcessTerminalView` wrapped in `NSViewRepresentable` as the terminal workhorse. Do not manage PTY file descriptors manually. Shell out to `/usr/bin/ssh` for connections and `/usr/bin/ssh-keygen` for key generation.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftTerm | v1.12.0 (March 2024) | Terminal emulator + PTY management | Only mature pure-Swift terminal library; `LocalProcessTerminalView` handles PTY, SIGWINCH, and VT100 emulation; GPU Metal backend in v1.12 |
| Foundation.Process | macOS built-in | SSH arg construction (secondary role) | Used only to build the argument list; PTY is managed by SwiftTerm's `LocalProcess`, NOT a raw `Foundation.Process` |
| Security.framework | macOS built-in | Keychain password storage | `SecItemAdd`/`SecItemCopyMatching` — stable Apple API for per-session password storage |
| CryptoKit | macOS built-in | SSH key vault encryption | `AES.GCM` with `SymmetricKey` for AES-256-GCM; available since macOS 10.15 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing (`@Test` macro) | Swift 5.9+ | Unit tests | New tests in Phase 2 should use `@Test` (existing tests already use it) |
| XCTest | Built-in | Integration tests where Swift Testing falls short | Only for tests needing `XCTestCase` lifecycle hooks |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LocalProcessTerminalView | Manual `openpty()` + Foundation.Process | Apple DTS: "PTY is a royal pain in any language." SwiftTerm already solved it correctly. Manual approach requires unsafe C interop, signal handling, and FD lifecycle management. No benefit. |
| Shell to `/usr/bin/ssh-keygen` | `SecKeyCreateRandomKey` | Security framework cannot generate openssh-key-v1 format (the modern OpenSSH private key format). ssh-keygen produces correct Ed25519 keys that work everywhere. |
| Custom tab bar | `NSTabView` or `SwiftUI.TabView` | Neither supports scrollable, closable, reorderable document-style tabs. `TabView` on macOS renders as a segmented control, not a terminal-style tab strip. |

**Installation (SPM):**
```swift
// In Package.swift or Xcode > Add Package Dependency:
.package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.12.0")
```

---

## Architecture Patterns

### Recommended Project Structure (Phase 2 additions)

```
MobaAlt/
  Models/
    CommandSnippet.swift         # Reusable snippet model (TERM-05)
    PortForwardingRule.swift     # SSH port forward config (SSH-05)
  Views/
    AppShell/
      ContentView.swift          # MODIFY: add TabManager env + tab area
    Terminal/
      TerminalTabView.swift      # NSViewRepresentable wrapper for LocalProcessTerminalView
      TerminalTabBar.swift       # Custom scrollable tab bar UI
    Credentials/
      KeyVaultUnlockView.swift   # Master password sheet
      KeyVaultView.swift         # Add/view/remove stored keys
      CredentialPickerView.swift # Used in session editor
    SSH/
      PortForwardingEditorView.swift  # Configure -L/-R/-D rules
      ActiveTunnelsView.swift    # SSH-06: list active tunnels
  Services/
    TabManager.swift             # @Observable: open/close/switch tabs
    SSHConnection.swift          # Wraps LocalProcessTerminalView lifecycle
    KeychainManager.swift        # Security.framework actor
    KeyVaultManager.swift        # AES-GCM encrypted vault actor
    SessionLogWriter.swift       # TERM-04: file-based session logging
  Utilities/
    SSHArgumentBuilder.swift     # Builds ssh argv from SSHConfig
```

### Pattern 1: LocalProcessTerminalView as the SSH Terminal

**What:** Use SwiftTerm's `LocalProcessTerminalView` (an `NSView` subclass) to spawn `/usr/bin/ssh` inside a PTY. This class handles `openpty()`, process lifecycle, SIGWINCH, and VT100 emulation internally.

**When to use:** All SSH terminal sessions.

**The key insight:** `LocalProcessTerminalView` is NOT just for local shells — its `startProcess(executable:args:environment:execName:currentDirectory:)` method accepts any executable. Pass `/usr/bin/ssh` with appropriate args.

```swift
// Source: SwiftTerm GitHub README + LocalProcess API docs
import SwiftTerm

class SSHTerminalView: LocalProcessTerminalView, LocalProcessTerminalViewDelegate {

    func startSSH(config: SSHConfig, environment: [String]) {
        // Set environment: TERM must be xterm-256color for color/TUI support
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        // SSH_AUTH_SOCK is already in the inherited environment for agent forwarding

        let args = SSHArgumentBuilder.build(from: config)
        // args example: ["-p", "22", "-l", "alice", "192.168.1.10"]

        startProcess(
            executable: "/usr/bin/ssh",
            args: args,
            environment: env.map { "\($0.key)=\($0.value)" },
            execName: "ssh"
        )
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func processTerminated(_ source: LocalProcessTerminalView, exitCode: Int32?) {
        // Called when ssh exits — update connection state, show reconnect option
        DispatchQueue.main.async {
            // Notify TabManager that this tab disconnected
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // SwiftTerm automatically handles SIGWINCH; this is the notification callback
        // No manual kill(pid, SIGWINCH) needed — LocalProcess does it
    }
}
```

### Pattern 2: NSViewRepresentable Bridge for SwiftUI

**What:** Wrap `SSHTerminalView` (an `NSView` subclass) for embedding in SwiftUI `ContentView`.

**When to use:** Whenever a terminal view must live inside a SwiftUI layout.

```swift
// Source: SwiftTerm README + NSViewRepresentable Apple docs
struct TerminalViewWrapper: NSViewRepresentable {
    @ObservedObject var connection: SSHConnectionViewModel

    func makeNSView(context: Context) -> SSHTerminalView {
        let view = SSHTerminalView()
        view.processDelegate = context.coordinator
        connection.attachView(view)
        return view
    }

    func updateNSView(_ nsView: SSHTerminalView, context: Context) {
        // Terminal manages its own rendering — typically no-op
        // Only called for SwiftUI state changes that affect the wrapper
    }

    func makeCoordinator() -> SSHConnectionViewModel {
        connection
    }
}
```

### Pattern 3: TerminalViewDelegate Data Bridge

**What:** SwiftTerm's `TerminalViewDelegate` is how all terminal I/O is routed. For session logging (TERM-04), intercept in the delegate.

**Key delegate methods:**

```swift
// Source: SwiftTerm UIKitSshTerminalView.swift (official iOS SSH example)

// Called when user types (terminal → ssh process)
func send(source: TerminalView, data: ArraySlice<UInt8>) {
    // LocalProcessTerminalView handles this internally — no custom impl needed for local process
    // For logging: optionally mirror to log writer here
}

// Called when terminal data is received (ssh process → terminal display)
// For LocalProcessTerminalView this is handled internally.
// For TERM-04 logging, subclass and intercept in feed():
override func feed(byteArray: ArraySlice<UInt8>) {
    super.feed(byteArray: byteArray)
    sessionLogWriter?.write(byteArray)  // tee to log file
}

// Called when terminal size changes (view resize → SIGWINCH to ssh)
func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    // LocalProcessTerminalView sends SIGWINCH automatically
    // If using SSH ControlMaster for SFTP: notify the SFTP session too
}
```

### Pattern 4: Custom Tab Bar

**What:** A horizontal, scrollable, closable tab bar implemented in pure SwiftUI.

**When to use:** The main content area tab strip. `SwiftUI.TabView` and `NSTabView` are not suitable — they render as segmented controls/non-closable widgets.

```swift
// Custom scrollable tab bar
struct TerminalTabBar: View {
    @Bindable var tabManager: TabManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    TabBarItem(
                        tab: tab,
                        isActive: tab.id == tabManager.activeTabId,
                        onSelect: { tabManager.activateTab(tab.id) },
                        onClose: { tabManager.closeTab(tab.id) }
                    )
                }
            }
        }
        .frame(height: 32)
        .background(.regularMaterial)
    }
}
```

### Pattern 5: SSH Argument Builder

**What:** Pure function that converts `SSHConfig` → `[String]` argv for `/usr/bin/ssh`.

**Critical rule:** Prefer passing only what the user explicitly configured. Let `~/.ssh/config` handle the rest (SSH-03).

```swift
// Source: OpenSSH man page + project SSHConfig model
struct SSHArgumentBuilder {
    static func build(from config: SSHConfig) -> [String] {
        var args: [String] = []

        // Port — only if non-standard
        if config.port != 22 {
            args += ["-p", "\(config.port)"]
        }

        // Username — only if set
        if !config.username.isEmpty {
            args += ["-l", config.username]
        }

        // Auth method
        switch config.authMethod {
        case .privateKey:
            if !config.privateKeyPath.isEmpty {
                args += ["-i", config.privateKeyPath]
            }
        case .agent:
            args += ["-A"]  // Enable agent forwarding
        case .password:
            break  // SSH will prompt; password auth is interactive
        }

        // Agent forwarding (SSH-04) — explicit flag if enabled regardless of auth method
        if config.agentForwarding && config.authMethod != .agent {
            args += ["-A"]
        }

        // X11 forwarding
        if config.x11Forwarding {
            args += ["-X"]
        }

        // Port forwarding rules (SSH-05)
        for rule in config.portForwardingRules {
            switch rule.direction {
            case .local:   args += ["-L", "\(rule.localPort):localhost:\(rule.remotePort)"]
            case .remote:  args += ["-R", "\(rule.remotePort):localhost:\(rule.localPort)"]
            case .dynamic: args += ["-D", "\(rule.localPort)"]
            }
        }

        // Hostname always last
        args.append(config.hostname)

        return args
    }
}
```

### Pattern 6: Keychain Manager Actor

**What:** Thread-safe wrapper around `Security.framework` `SecItem*` APIs.

```swift
// Source: Apple Security.framework documentation (stable API)
actor KeychainManager {
    private let service = "com.mobaalt.MobaAlt"

    func savePassword(_ password: String, for sessionId: UUID) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: sessionId.uuidString,
            kSecValueData: Data(password.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try updatePassword(password, for: sessionId)
        } else if status != errSecSuccess {
            throw KeychainError.operationFailed(status)
        }
    }

    func getPassword(for sessionId: UUID) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: sessionId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deletePassword(for sessionId: UUID) throws { ... }
}
```

### Pattern 7: SSH Key Vault (AES-256-GCM)

**What:** Encrypted file storing SSH private key material. Unlocked once per session with master password.

```swift
// Source: Apple CryptoKit documentation; AES.GCM standard
actor KeyVaultManager {
    private var vaultKey: SymmetricKey?   // held in memory after unlock
    private let vaultURL: URL             // ~/Library/Application Support/MobaAlt/keyvault.enc

    func unlock(masterPassword: String) throws {
        let salt = loadSalt()   // persisted alongside vault
        let keyData = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(masterPassword.utf8)),
            salt: salt,
            outputByteCount: 32
        )
        vaultKey = keyData
        // Verify by attempting to decrypt the vault
        _ = try decryptVault()
    }

    func addKey(name: String, privateKeyData: Data) throws {
        guard let key = vaultKey else { throw VaultError.locked }
        var vault = try decryptVault()
        vault[name] = privateKeyData
        try encryptAndSave(vault, with: key)
    }

    private func encryptAndSave(_ vault: [String: Data], with key: SymmetricKey) throws {
        let encoded = try JSONEncoder().encode(vault)
        let sealed = try AES.GCM.seal(encoded, using: key)
        try sealed.combined!.write(to: vaultURL, options: .atomic)
    }
}
```

### Pattern 8: SSH ControlMaster Socket Setup (Phase 3 preparation)

**What:** Each SSH session should establish a ControlMaster socket so that the SFTP session in Phase 3 can reuse the connection without re-authentication.

**When to use:** Include the `-o ControlMaster=auto` and `-o ControlPath=...` flags in the SSH args. The terminal session IS the master; SFTP will use `-o ControlMaster=no -o ControlPath=<same socket>`.

```swift
// Source: OpenSSH man page ssh_config(5)
static func controlPath(for sessionId: UUID) -> String {
    // macOS has a 104-char Unix socket path limit; use short UUID
    let shortId = sessionId.uuidString.prefix(8)
    return "/tmp/mobaalt-\(shortId).sock"
}

// Add to SSH args in SSHArgumentBuilder:
args += ["-o", "ControlMaster=auto"]
args += ["-o", "ControlPath=\(controlPath(for: session.id))"]
args += ["-o", "ControlPersist=no"]  // socket dies when terminal exits
```

### Anti-Patterns to Avoid

- **Manual PTY with Foundation.Process:** Apple DTS explicitly calls this "a royal pain in any language." SwiftTerm's `LocalProcessTerminalView` already handles it. Do not duplicate.
- **Setting DISPLAY before spawning SSH:** Do not set `DISPLAY` in the SSH process environment for X11 forwarding — SSH sets the remote `DISPLAY` automatically via `-X`/`-Y`. Setting it manually breaks per-session isolation.
- **Storing credentials in SessionDefinition:** `SSHConfig` must contain only a reference UUID, not the actual password or key data. Phase 1 already enforces this (`privateKeyPath` stores a path to the vault entry, not the key itself).
- **SwiftUI.TabView for terminal tabs:** Renders as a segmented control on macOS. Not suitable for closable, scrollable document-style tabs.
- **SecKeyCreateRandomKey for SSH key generation:** Cannot produce openssh-key-v1 format. Use `/usr/bin/ssh-keygen` via `Foundation.Process`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PTY allocation and management | `posix_openpt` + `grantpt` + `unlockpt` + signal handlers | `LocalProcessTerminalView.startProcess()` | SwiftTerm already implements this correctly, including SIGWINCH, resize, and cleanup |
| VT100/xterm escape sequence parsing | Any custom terminal parsing | SwiftTerm `TerminalView` | Hundreds of escape sequences; SwiftTerm v1.12 has GPU Metal backend and 69% throughput improvement |
| SSH key format encoding | DER/PEM/openssh-key-v1 serialization | `/usr/bin/ssh-keygen -t ed25519` subprocess | Apple Security framework cannot produce modern OpenSSH key format; ssh-keygen is the correct tool |
| Zombie process reaping | Custom `waitpid` loop | `LocalProcessTerminalView.processTerminated` delegate | SwiftTerm's `LocalProcess` reaps children; supplement with `process.terminationHandler` for belt-and-suspenders |
| Terminal rendering in SwiftUI | `Text`/`AttributedString` cells | `NSViewRepresentable` wrapping `LocalProcessTerminalView` | SwiftUI layout engine cannot meet terminal rendering performance requirements |

**Key insight:** SwiftTerm solves PTY management. OpenSSH binary solves SSH protocol. CryptoKit solves encryption. The app's job is to wire them together, not reimplement them.

---

## Common Pitfalls

### Pitfall 1: Not Setting TERM=xterm-256color

**What goes wrong:** vim, tmux, htop, and other TUI tools produce garbled output or refuse to run.

**Why it happens:** Without explicit `TERM` in the spawned process environment, it may inherit an empty or wrong value.

**How to avoid:** Always set `env["TERM"] = "xterm-256color"` and `env["LANG"] = "en_US.UTF-8"` before calling `startProcess`.

**Warning signs:** `vim` fails with "unknown terminal type"; colors missing; box-drawing characters show as question marks.

### Pitfall 2: SSH Agent Socket Not Inherited

**What goes wrong:** SSH agent forwarding fails even with `-A` flag; ssh-add keys are not available.

**Why it happens:** `LocalProcessTerminalView` may not inherit the exact same environment as the user's shell. `SSH_AUTH_SOCK` must be explicitly carried through.

**How to avoid:** Include `ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"]` in the environment passed to `startProcess`. Log its value at connection time for debugging.

**Warning signs:** `ssh-add -l` inside the session shows "Could not open a connection to your authentication agent."

### Pitfall 3: Keychain Items Lost After App Re-sign

**What goes wrong:** After updating the app (even during development with different provisioning), `SecItemCopyMatching` returns `errSecItemNotFound` for previously stored passwords.

**Why it happens:** Keychain ACLs are tied to the signing identity. Changing from development to distribution cert, or signing with a different team, breaks access.

**How to avoid:** Use `kSecAttrAccessGroup` = `"$(AppIdentifierPrefix)com.mobaalt.MobaAlt"` to scope items. Lock down the signing identity before storing any production credentials. Test the full cycle: store → re-sign → retrieve.

**Warning signs:** Users must re-enter passwords after every app update.

### Pitfall 4: Tab Lifecycle Memory Leaks

**What goes wrong:** Closing a tab does not release the `LocalProcessTerminalView`, leading to unbounded memory growth and orphaned SSH processes.

**Why it happens:** SwiftUI `NSViewRepresentable` views can retain strong references through closures, delegate patterns, or the SwiftUI view graph if not properly unwired.

**How to avoid:** On tab close: call `process.terminate()`, nil out delegate references, remove the `NSViewRepresentable` from the view hierarchy before releasing `TabItem`. Verify with Instruments Allocations by opening/closing 10 tabs.

**Warning signs:** `ps aux | grep ssh` shows accumulating orphaned processes after tab closes.

### Pitfall 5: Unix Socket Path Length Limit for ControlMaster

**What goes wrong:** `ControlPath` socket fails to create on macOS with "unix listener too long" error.

**Why it happens:** macOS `sockaddr_un.sun_path` is limited to 104 characters. Full paths with UUID strings easily exceed this.

**How to avoid:** Use `/tmp/mobaalt-XXXXXXXX.sock` (8-char UUID prefix). Alternatively, use `~/.ssh/control/` (per OpenSSH documentation for macOS). Validate path length before passing to ssh.

**Warning signs:** SSH connection hangs or fails immediately when ControlPath is set; `ssh -vvv` shows socket creation failure.

### Pitfall 6: Password Auth Interactive Prompt Handling

**What goes wrong:** When SSH prompts for a password, the user cannot type it — the terminal appears frozen or the connection times out.

**Why it happens:** `LocalProcessTerminalView` runs SSH inside a PTY, which means SSH CAN present interactive prompts. However, if `SSH_ASKPASS` is set in the environment or if the terminal is not properly configured, SSH may try a GUI askpass program or fail silently.

**How to avoid:** Do NOT set `SSH_ASKPASS` or `DISPLAY` in the SSH process environment (unless X11 forwarding is requested). Let the PTY handle interactive password prompts naturally — the user types directly into the terminal. This is the correct behavior for password auth.

**Warning signs:** SSH exits immediately with no password prompt when `authMethod == .password`.

### Pitfall 7: Vault Decryption Key Derivation Must Be Deterministic

**What goes wrong:** The vault cannot be decrypted after app restart because the key derivation produces a different key each time.

**Why it happens:** Using a random salt that is not persisted, or using `Date()` as an input to key derivation.

**How to avoid:** Generate the salt once, store it alongside the vault (it does not need to be secret). Use `HKDF<SHA256>.deriveKey(inputKeyMaterial:salt:outputByteCount:)` with the persisted salt. Store the salt at `~/Library/Application Support/MobaAlt/keyvault.salt` using atomic write.

---

## Code Examples

Verified patterns from official sources:

### LocalProcessTerminalView startProcess (SSH)

```swift
// Source: SwiftTerm GitHub — LocalProcessTerminalView API
// v1.12.0 signature verified via SwiftPackageRegistry
let terminal = LocalProcessTerminalView(frame: .zero)
terminal.startProcess(
    executable: "/usr/bin/ssh",
    args: ["-p", "22", "-l", "alice", "192.168.1.10"],
    environment: ["TERM=xterm-256color", "LANG=en_US.UTF-8"],
    execName: "ssh"
)
```

### CryptoKit AES-GCM Encrypt/Decrypt

```swift
// Source: Apple CryptoKit documentation
import CryptoKit

// Encrypt
let key = SymmetricKey(size: .bits256)
let data = Data("secret key material".utf8)
let sealed = try AES.GCM.seal(data, using: key)
let ciphertext = sealed.combined!  // nonce + ciphertext + tag

// Decrypt
let box = try AES.GCM.SealedBox(combined: ciphertext)
let plaintext = try AES.GCM.open(box, using: key)
```

### Keychain Store/Retrieve

```swift
// Source: Apple Security.framework documentation
import Security

// Store
let attrs: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "com.mobaalt.MobaAlt",
    kSecAttrAccount: sessionId.uuidString,
    kSecValueData: Data(password.utf8),
    kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
]
SecItemAdd(attrs as CFDictionary, nil)

// Retrieve
let query: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "com.mobaalt.MobaAlt",
    kSecAttrAccount: sessionId.uuidString,
    kSecReturnData: true,
    kSecMatchLimit: kSecMatchLimitOne
]
var result: AnyObject?
SecItemCopyMatching(query as CFDictionary, &result)
```

### SSH Key Generation via Subprocess

```swift
// Source: OpenSSH man page; ssh-keygen is at /usr/bin/ssh-keygen on macOS
// Rationale: SecKeyCreateRandomKey cannot produce openssh-key-v1 format
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
process.arguments = [
    "-t", "ed25519",
    "-C", comment,
    "-f", outputPath,   // write to temp path, then move to vault
    "-N", passphrase    // empty string for no passphrase (vault handles encryption)
]
try process.run()
process.waitUntilExit()
// Read generated files, store in vault, delete temp files
```

### Feed SSH Output to Terminal (TerminalViewDelegate pattern)

```swift
// Source: SwiftTerm UIKitSshTerminalView.swift (official iOS SSH example)
// For custom (non-LocalProcess) SSH integration if needed in future phases:
func channelDataReceived(data: [UInt8]) {
    let chunkSize = 1024
    var offset = 0
    while offset < data.count {
        let end = min(offset + chunkSize, data.count)
        let chunk = data[offset..<end]
        DispatchQueue.main.async { [weak terminalView] in
            terminalView?.feed(byteArray: chunk)
        }
        offset = end
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Foundation.Process` + manual `openpty()` | `LocalProcessTerminalView.startProcess()` | SwiftTerm ~v1.0 | Eliminates unsafe PTY C interop |
| `NSTabView` for terminal tabs | Custom SwiftUI `ScrollView`-based tab bar | SwiftUI 3.0+ (macOS 12+) | Full control over tab appearance |
| `ObservableObject` + `@Published` | `@Observable` macro (Swift 5.9+) | Xcode 15 / macOS 14 | No manual `@Published`; simpler ViewModels |
| `altool` for notarization | `xcrun notarytool` | macOS Monterey | `altool` deprecated, removed in recent Xcode |
| RSA-2048 SSH keys | Ed25519 SSH keys | OpenSSH ~7.x (2014, mainstream ~2020) | Smaller, faster, more secure; modern standard |
| SwiftTerm CPU renderer | SwiftTerm GPU Metal renderer (v1.12.0) | March 2024 | Significant throughput improvement; use v1.12+ |

**Deprecated/outdated:**
- `NSTask`: Renamed to `Foundation.Process` in Swift — do not use the old name
- `altool`: Removed from recent Xcode — use `notarytool`
- `LocalProcess.forkpty` path: SwiftTerm v1.12 uses Subprocess API on modern macOS; no manual `forkpty` needed

---

## Open Questions

1. **SwiftTerm's `startProcess` parameter exact signature on v1.12**
   - What we know: Method exists and accepts `executable`, `args`, `environment`, `execName` parameters; `currentDirectory` was added in a recent release
   - What's unclear: Whether `environment` is `[String]` (KEY=VALUE format) or `[String: String]` — the iOS SSH example uses NIO, not LocalProcess
   - Recommendation: At Wave 0 kickoff, read `LocalProcessTerminalView.swift` source directly from the SPM checkout to confirm signature before writing SSHConnection code

2. **Password-based SSH auth with PTY prompts**
   - What we know: PTY-based SSH supports interactive password prompts; the user types directly into the terminal
   - What's unclear: Whether the app should pre-provide passwords programmatically (via stdin pipe before PTY attach) or let users type them each time
   - Recommendation: For Phase 2, let users type passwords interactively (simpler, more secure). Phase 2+ credential integration can use `sshpass`-style pre-fill or `~/.ssh/config` credential helpers, but that is explicitly deferred to credential-based auth flows.

3. **Session logging atomic writes and file handle management (TERM-04)**
   - What we know: Session output must be logged to a file per session
   - What's unclear: Whether to use `FileHandle.write()` directly or buffer and flush on a background queue
   - Recommendation: Use a dedicated `actor SessionLogWriter` with a `FileHandle` opened at connection start. Write synchronously within the actor. Close on disconnect.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` macro, Swift 5.9+) |
| Config file | None — Xcode auto-discovers `@Test` functions |
| Quick run command | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS' -only-testing MobaAltTests/KeychainManagerTests` |
| Full suite command | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SSH-01 | SSHArgumentBuilder builds correct argv | unit | `xcodebuild test ... -only-testing MobaAltTests/SSHArgumentBuilderTests` | Wave 0 |
| SSH-02 | KeychainManager stores/retrieves password | unit | `xcodebuild test ... -only-testing MobaAltTests/KeychainManagerTests` | Wave 0 |
| SSH-03 | SSHArgumentBuilder omits -l when username empty | unit | `xcodebuild test ... -only-testing MobaAltTests/SSHArgumentBuilderTests` | Wave 0 |
| SSH-04 | SSHArgumentBuilder adds -A for agentForwarding | unit | `xcodebuild test ... -only-testing MobaAltTests/SSHArgumentBuilderTests` | Wave 0 |
| SSH-05 | SSHArgumentBuilder maps PortForwardingRule to flags | unit | `xcodebuild test ... -only-testing MobaAltTests/SSHArgumentBuilderTests` | Wave 0 |
| SSH-06 | TabManager exposes active connections with port forward state | unit | `xcodebuild test ... -only-testing MobaAltTests/TabManagerTests` | Wave 0 |
| SSH-07 | ssh-keygen subprocess produces .pub + private key files | integration | `xcodebuild test ... -only-testing MobaAltTests/SSHKeyGeneratorTests` | Wave 0 |
| TERM-01 | TerminalViewWrapper makeNSView returns non-nil view | unit | `xcodebuild test ... -only-testing MobaAltTests/TerminalViewWrapperTests` | Wave 0 |
| TERM-02 | TabManager openTab increments tab count | unit | `xcodebuild test ... -only-testing MobaAltTests/TabManagerTests` | Wave 0 |
| TERM-03 | TERM env var is xterm-256color in startProcess args | unit | `xcodebuild test ... -only-testing MobaAltTests/SSHConnectionTests` | Wave 0 |
| TERM-04 | SessionLogWriter writes bytes to file | unit | `xcodebuild test ... -only-testing MobaAltTests/SessionLogWriterTests` | Wave 0 |
| TERM-05 | CommandSnippet model is Codable | unit | `xcodebuild test ... -only-testing MobaAltTests/CommandSnippetTests` | Wave 0 |
| CRED-01 | KeychainManager roundtrip: save/get/delete | unit | `xcodebuild test ... -only-testing MobaAltTests/KeychainManagerTests` | Wave 0 |
| CRED-02 | KeyVaultManager encrypts/decrypts vault file | unit | `xcodebuild test ... -only-testing MobaAltTests/KeyVaultManagerTests` | Wave 0 |
| CRED-03 | KeyVaultManager unlock with wrong password throws | unit | `xcodebuild test ... -only-testing MobaAltTests/KeyVaultManagerTests` | Wave 0 |
| CRED-04 | KeyVaultManager addKey/removeKey round trip | unit | `xcodebuild test ... -only-testing MobaAltTests/KeyVaultManagerTests` | Wave 0 |

Note: SSH-01/TERM-01 involve actual terminal UI — cannot be fully automated via unit test. The unit tests validate the supporting logic (arg building, connection state, view construction); actual SSH connectivity is validated manually during human-verify.

### Sampling Rate

- **Per task commit:** Run the specific test file for the component just implemented
- **Per wave merge:** `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `MobaAltTests/SSHArgumentBuilderTests.swift` — covers SSH-01, SSH-03, SSH-04, SSH-05
- [ ] `MobaAltTests/KeychainManagerTests.swift` — covers CRED-01
- [ ] `MobaAltTests/KeyVaultManagerTests.swift` — covers CRED-02, CRED-03, CRED-04
- [ ] `MobaAltTests/TabManagerTests.swift` — covers TERM-02, SSH-06
- [ ] `MobaAltTests/SessionLogWriterTests.swift` — covers TERM-04
- [ ] `MobaAltTests/SSHKeyGeneratorTests.swift` — covers SSH-07
- [ ] `MobaAltTests/CommandSnippetTests.swift` — covers TERM-05
- [ ] `MobaAltTests/SSHConnectionTests.swift` — covers TERM-03 (env validation)
- [ ] `MobaAltTests/TerminalViewWrapperTests.swift` — covers TERM-01

---

## Sources

### Primary (HIGH confidence)

- [SwiftTerm GitHub repo — migueldeicaza/SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) — LocalProcessTerminalView API, TerminalViewDelegate, v1.12.0 release notes
- [SwiftTerm iOS SSH example — UIKitSshTerminalView.swift](https://github.com/migueldeicaza/SwiftTerm/blob/main/TerminalApp/iOSTerminal/UIKitSshTerminalView.swift) — feed() chunking pattern, sizeChanged delegate, send delegate
- Apple CryptoKit documentation — AES.GCM seal/open, SymmetricKey, HKDF
- Apple Security.framework documentation — SecItemAdd, SecItemCopyMatching, kSecAttrAccessibleWhenUnlocked
- Phase 1 codebase — SSHConfig model (agentForwarding, privateKeyPath, x11Forwarding fields confirmed); entitlements (Hardened Runtime, no sandbox); ConnectionProtocol discriminator

### Secondary (MEDIUM confidence)

- [Swift Forums — Process with PTY](https://forums.swift.org/t/swift-process-with-psuedo-terminal/51457) — Confirms PTY is difficult manually; Apple DTS recommendation
- [Apple Developer Forums — Swift Process PTY](https://developer.apple.com/forums/thread/688534) — openpty() approach; confirms LocalProcessTerminalView is the correct abstraction
- [OpenSSH ControlMaster documentation](https://wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing) — ControlPath token substitution; macOS 104-char socket limit

### Tertiary (LOW confidence — verify before use)

- SwiftTerm v1.12.0 release date noted as "March 15, 2024" by WebFetch — should pin exact commit/tag in Package.swift
- `startProcess` environment parameter format (`[String]` vs `[String: String]`) — verify from SPM checkout source at implementation time

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — SwiftTerm verified via GitHub; Security.framework and CryptoKit are stable Apple APIs
- Architecture: HIGH — Patterns verified against SwiftTerm source and iOS SSH example; PTY approach confirmed
- Pitfalls: HIGH — PTY difficulty confirmed by Apple DTS; Keychain ACL issue is well-documented; socket path limit is documented macOS constraint
- Test infrastructure: HIGH — Existing test suite uses Swift Testing `@Test` macro; pattern confirmed from Phase 1 test files

**Research date:** 2026-03-20
**Valid until:** 2026-06-20 (SwiftTerm is actively maintained; re-verify if > 90 days old before implementation)
