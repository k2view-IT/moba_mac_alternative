# Feature Landscape

**Domain:** macOS remote session manager (MobaXterm alternative)
**Researched:** 2026-03-19
**Confidence:** MEDIUM (based on training data knowledge of MobaXterm, Royal TSX, Termius, SecureCRT, iTerm2 -- web verification was unavailable)

## Competitive Landscape Overview

| Product | Platform | Strengths | Weakness on macOS |
|---------|----------|-----------|-------------------|
| MobaXterm | Windows only | All-in-one: SSH + X11 + SFTP + RDP/VNC + tabs + session manager | Does not exist on macOS -- this is the gap |
| Royal TSX | macOS + Windows | Plugin architecture, RDP/VNC native, credential vault | No built-in terminal (uses plugin), complex UI, expensive for teams |
| Termius | Cross-platform | Modern UI, cloud sync, team sharing, snippets | Subscription pricing, no X11, no RDP/VNC, limited SFTP |
| SecureCRT | macOS + Windows | Rock-solid terminal emulation, scripting, enterprise | Dated UI, expensive, no built-in SFTP panel, no RDP/VNC |
| iTerm2 | macOS only | Best macOS terminal, free, triggers, profiles | Not a session manager -- no saved connections, no RDP/VNC, no SFTP |

**The gap:** No macOS app combines MobaXterm's unified session management (SSH + RDP + VNC + SFTP + X11) in a single tabbed interface. Users cobble together iTerm2 + Microsoft Remote Desktop + Screen Sharing + Cyberduck/Transmit. This project fills that gap.

---

## Table Stakes

Features users expect from a MobaXterm replacement. Missing any of these means IT/DevOps users will not switch.

### Session Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Saved sessions with name, host, port, username, auth method | Core of MobaXterm -- every competitor has this | Low | Foundation of the entire app |
| Hierarchical folder organization | MobaXterm, Royal TSX, Termius all have this | Low | Tree view in sidebar |
| Session search/filter | With 50+ servers, unusable without search | Low | Real-time filter on name/host/tag |
| Quick connect (ad-hoc without saving) | Power users need fast one-off connections | Low | Address bar or Cmd+K palette |
| Duplicate session | Common workflow: connect to same server in new tab | Low | Right-click context menu |
| Session import/export (JSON or similar) | Team sharing, backup, migration from other tools | Medium | Custom JSON format initially; MobaXterm .mxtsessions import is a differentiator |
| Connection status indicators | Must see at a glance which sessions are connected/disconnected | Low | Color dot or icon in sidebar |

### SSH Features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Password and key-based authentication | Basic SSH requirement | Low | Support both id_rsa/ed25519 and password |
| SSH key management (select per session) | MobaXterm and all competitors support this | Low | File picker + remember path per session |
| SSH agent forwarding | Required for bastion/jump host workflows | Low | Pass -A flag or configure per session |
| Local port forwarding | Core DevOps workflow (access remote DB locally) | Medium | UI to configure -L mappings per session |
| Remote port forwarding | Less common but expected by MobaXterm users | Medium | UI to configure -R mappings per session |
| Dynamic port forwarding (SOCKS proxy) | Power user feature but table stakes for MobaXterm parity | Medium | UI to configure -D per session |
| Jump host / bastion (ProxyJump) | Standard in enterprise environments | Medium | Configure chain of hosts; SSH -J support |
| Keep-alive / auto-reconnect | Sessions drop; MobaXterm auto-reconnects | Low | ServerAliveInterval + reconnect on disconnect |
| SSH config file respect | Many users have complex ~/.ssh/config | Medium | Parse and honor existing SSH config, allow override per session |
| Multiple authentication methods (keyboard-interactive, GSSAPI) | Enterprise environments use various auth | Medium | Kerberos/GSSAPI can be deferred but keyboard-interactive is table stakes |

### Terminal Emulator

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Tabbed interface | Core MobaXterm UX -- every session in a tab | Medium | SwiftTerm + tab management |
| Split panes (horizontal + vertical) | MobaXterm and iTerm2 both have this | High | Requires terminal view splitting logic |
| Scrollback buffer (configurable) | Every terminal has this | Low | Default 10K lines, configurable |
| Search in terminal output | iTerm2, MobaXterm -- find text in scrollback | Medium | Cmd+F search overlay |
| Copy on select / paste on right-click | MobaXterm default behavior; configurable | Low | Preference toggle |
| Color schemes / themes | Visual customization is expected | Low | Ship 5-10 built-in themes + custom |
| Font selection and size | Basic terminal preference | Low | System font picker |
| Terminal bell handling | Visual bell, audio bell, or off | Low | Preference |
| ANSI/xterm-256color support | Modern CLI tools require this | Medium | SwiftTerm handles this |
| Unicode/emoji rendering | Modern terminals must handle UTF-8 | Medium | SwiftTerm handles this |
| Configurable keyboard shortcuts | Power users remap keys | Medium | Preferences pane |

### SFTP File Browser

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Side panel SFTP browser alongside SSH session | MobaXterm's signature feature -- automatic SFTP when SSH connects | High | Auto-open SFTP channel on SSH connection |
| Drag and drop upload/download | Visual file transfer | Medium | macOS drag-and-drop integration |
| Download/upload progress indicator | Users need to know transfer status | Medium | Progress bar per transfer |
| Navigate remote filesystem (tree or list) | Basic SFTP browsing | Medium | Directory listing with back/forward |
| Open remote file in local editor | MobaXterm does this; edit-save-upload | High | Temp download, watch for changes, re-upload |
| File permissions display | ls -la equivalent in GUI | Low | Show permissions, owner, size, date |

### Credential Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| macOS Keychain integration for passwords | Native macOS credential storage | Medium | Use Security framework |
| SSH key vault (encrypted storage) | Protect private keys at rest | High | AES-encrypted local vault as per PROJECT.md |
| Master password for key vault | Protect the vault itself | Medium | Derive encryption key from master password |
| Per-session credential assignment | Different servers = different credentials | Low | Credential picker in session config |
| SSH agent integration | Use system ssh-agent or built-in | Medium | Forward keys from agent, or load from vault into agent |

### RDP/VNC

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| RDP session management (save connection details) | MobaXterm has built-in RDP | Low | Store host, port, username, domain, resolution |
| VNC session management | MobaXterm has built-in VNC | Low | Store host, port, password |
| Launch RDP via Microsoft Remote Desktop or system tool | PROJECT.md decision -- delegate to system apps | Medium | Use URL schemes or AppleScript to launch |
| Launch VNC via macOS Screen Sharing | PROJECT.md decision -- delegate to system apps | Low | `vnc://` URL scheme opens Screen Sharing.app |
| Tab integration for RDP/VNC sessions | Sessions appear in tab bar even if external app | High | At minimum, track status; ideally embed window |

### X11 Forwarding

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| X11 forwarding toggle per session | MobaXterm's embedded X server is a key feature | Medium | SSH -X or -Y flag per session |
| XQuartz detection and install guidance | PROJECT.md requirement | Low | Check /opt/X11/bin/xquartz or `which xquartz` |
| DISPLAY variable auto-configuration | Must set DISPLAY correctly for XQuartz | Low | Detect XQuartz socket, set env var |

---

## Differentiators

Features that would set this app apart from Royal TSX, Termius, and iTerm2. Not expected, but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| MobaXterm session import (.mxtsessions) | Zero-friction migration for teams switching from Windows | Medium | Parse MobaXterm INI-style config format |
| Command snippets library | Save and reuse common commands across sessions (Termius has this, MobaXterm has macros) | Medium | Searchable snippet palette, insert into active terminal |
| Multi-exec (broadcast input to multiple sessions) | Type once, execute on N servers simultaneously -- MobaXterm MultiExec | High | Broadcast keystroke mode across selected tabs |
| SSH tunnel manager with visual UI | Visual diagram of tunnel mappings (local:remote) with start/stop per tunnel | High | Dedicated tunnel management panel |
| Embedded RDP/VNC viewer (not external app) | True tabbed experience for RDP/VNC instead of launching external apps | Very High | Would require FreeRDP/libvnc integration -- consider for v2 |
| Session tagging and smart folders | Tag sessions (prod, staging, dev) and auto-filter | Low | Tags + saved filters |
| Connection health dashboard | Overview of all saved sessions: which are reachable, latency | Medium | Background ping/SSH check |
| Local terminal tab (no SSH, just local shell) | iTerm2 replacement -- run local commands in same app | Low | SwiftTerm with local PTY |
| Keyboard-driven command palette (Cmd+K) | Modern UX pattern (VS Code, Raycast) -- quick access to any action | Medium | Fuzzy search over sessions, commands, actions |
| Auto-SFTP on SSH connect | MobaXterm does this automatically -- huge workflow win | Medium | Open SFTP channel automatically when SSH session starts |
| Credential sync via iCloud Keychain | Share credentials across Macs without cloud service | Medium | Use iCloud Keychain APIs |
| SSH config auto-discovery | Import sessions from ~/.ssh/config automatically | Medium | Parse SSH config, create sessions from Host entries |
| Session notes / documentation | Attach notes to servers (runbooks, IPs, contact info) | Low | Markdown notes field per session |
| Appearance follows macOS (light/dark mode) | Native feel that Royal TSX and Termius sometimes miss | Low | SwiftUI auto dark mode support |
| Touch Bar support (older Macs) / Menu Bar quick connect | macOS-native affordances | Low | Nice-to-have, not critical |

---

## Anti-Features

Features to deliberately NOT build in v1. Either out of scope, not valuable for target audience, or dangerous scope creep.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Built-in text editor | Massive scope; users have vim/nano/VS Code | Open remote files in system editor via SFTP download |
| Cloud sync of sessions | Adds auth, backend, privacy concerns -- PROJECT.md excludes this | Local JSON export/import for sharing; iCloud Keychain for creds only |
| Serial/Telnet connections | Niche protocols; PROJECT.md excludes | Defer to v2+ if demanded |
| Built-in RDP protocol implementation | FreeRDP integration is very complex; macOS has Microsoft Remote Desktop | Delegate to system apps; embed in v2 if validated |
| Built-in VNC protocol implementation | Same as RDP -- macOS Screen Sharing works well | Use vnc:// URL scheme |
| Web-based SSH (browser terminal) | Different product; adds web server complexity | Stay native macOS |
| Mobile companion app | PROJECT.md: desktop only | Stay macOS-only |
| Plugin/extension system | Massive architecture overhead for v1 | Build monolithic first; extract plugin points in v2 |
| App Store distribution | Sandboxing restrictions conflict with SSH agent, XQuartz, system tool launching | DMG distribution per PROJECT.md |
| Multi-user / RBAC | Enterprise feature; needs backend | Single-user local app for v1 |
| Ansible/Terraform integration | Scope creep into DevOps tooling | Users run these in the terminal; no special integration needed |
| Chat/messaging between team members | Not a session manager's job | Use Slack/Teams |
| Password generator | Available elsewhere; not core value | Users generate passwords with their preferred tool |
| Automatic server discovery (network scan) | Nice but complex and potentially noisy on enterprise networks | Manual session creation + SSH config import |

---

## Feature Dependencies

```
Core Foundation
  Session Model (CRUD, folders, search)
    |
    +---> SSH Connection Engine
    |       |
    |       +---> Terminal Emulator (SwiftTerm)
    |       |       |
    |       |       +---> Split Panes
    |       |       +---> Search in Output
    |       |       +---> Themes / Fonts
    |       |
    |       +---> SFTP Browser (auto-open on SSH connect)
    |       |       |
    |       |       +---> Drag & Drop Upload/Download
    |       |       +---> Remote File Edit
    |       |
    |       +---> Port Forwarding UI
    |       |       +---> Local / Remote / Dynamic
    |       |       +---> SSH Tunnel Manager (visual)
    |       |
    |       +---> X11 Forwarding
    |       |       +---> XQuartz Detection
    |       |
    |       +---> Jump Host / Bastion Support
    |       +---> SSH Agent Forwarding
    |       +---> Multi-Exec (broadcast)
    |
    +---> RDP Session Launcher
    |       +---> (v2: Embedded RDP viewer)
    |
    +---> VNC Session Launcher
    |       +---> (v2: Embedded VNC viewer)
    |
    +---> Credential Store
    |       +---> macOS Keychain (passwords)
    |       +---> SSH Key Vault (encrypted)
    |       +---> Master Password
    |
    +---> Session Import/Export
    |       +---> JSON format
    |       +---> MobaXterm .mxtsessions import
    |       +---> SSH config import
    |
    +---> Tab Management
            +---> Tab bar
            +---> Split view
            +---> Local terminal tab
```

Key dependency chains:
- **Terminal emulator must exist before SSH sessions can work** -- SwiftTerm integration is the foundation
- **SSH connection engine must exist before SFTP browser** -- SFTP rides on the SSH channel
- **Credential store should exist before session creation** -- sessions reference credentials
- **Tab management is parallel to connection types** -- can be built alongside SSH/RDP/VNC
- **X11 forwarding requires SSH to work first** -- it's an SSH session flag
- **Port forwarding UI requires SSH sessions** -- builds on top of connection engine
- **Multi-exec requires multiple active SSH sessions** -- late-stage feature

---

## MVP Recommendation

### Must Have (Phase 1 - Core)

1. **Session model** -- create, save, organize in folders, search (foundation for everything)
2. **SSH connections in embedded terminal** -- SwiftTerm integration, tabbed interface
3. **Credential management** -- macOS Keychain for passwords, SSH key selection per session
4. **Basic terminal features** -- tabs, scrollback, search, copy/paste, themes
5. **Quick connect** -- ad-hoc SSH without saving a session

### Should Have (Phase 2 - MobaXterm Parity)

6. **SFTP browser panel** -- auto-opens alongside SSH session (MobaXterm signature feature)
7. **Port forwarding UI** -- local/remote/dynamic forwarding per session
8. **Jump host / bastion support** -- ProxyJump configuration per session
9. **RDP/VNC session management** -- save + launch via system apps
10. **X11 forwarding** -- XQuartz detection, per-session toggle
11. **Split panes** -- horizontal and vertical terminal splits
12. **SSH config import** -- auto-discover sessions from ~/.ssh/config
13. **Session import/export** (JSON format)

### Nice to Have (Phase 3 - Differentiators)

14. **Multi-exec / broadcast mode**
15. **Command snippets library**
16. **MobaXterm session import**
17. **SSH tunnel manager (visual)**
18. **Session tagging and smart folders**
19. **Connection health dashboard**
20. **Command palette (Cmd+K)**
21. **Local terminal tab**

### Defer (v2+)

- Embedded RDP/VNC viewer (very high complexity)
- Plugin system
- Cloud sync
- Serial/Telnet

---

## Complexity Budget Estimate

| Phase | Features | Estimated Complexity |
|-------|----------|---------------------|
| Phase 1 (Core) | Session model, SSH/terminal, credentials, tabs | High -- SwiftTerm integration is the riskiest piece |
| Phase 2 (Parity) | SFTP, port forwarding, jump hosts, RDP/VNC launch, X11, splits | High -- SFTP browser is substantial UI + protocol work |
| Phase 3 (Differentiators) | Multi-exec, snippets, tunnel manager, Cmd+K | Medium -- builds on solid foundation |

**Riskiest features:**
- SwiftTerm integration (terminal emulation quality determines entire app perception)
- SFTP browser with auto-open (requires parallel SSH channel management)
- Embedded RDP/VNC (defer to v2 -- use system app delegation for v1)

---

## Sources

- MobaXterm feature set: Training data knowledge (MEDIUM confidence -- well-documented product with stable feature set)
- Royal TSX feature set: Training data knowledge (MEDIUM confidence)
- Termius feature set: Training data knowledge (MEDIUM confidence)
- SecureCRT feature set: Training data knowledge (MEDIUM confidence)
- iTerm2 feature set: Training data knowledge (HIGH confidence -- widely documented macOS terminal)
- Feature categorization and priorities: Analysis based on PROJECT.md requirements and competitive positioning

**Note:** Web search and web fetch were unavailable during this research session. All competitive intelligence is based on training data (cutoff ~mid-2025). Feature sets of these products are mature and change slowly, so confidence is reasonable. Recommend verifying any specific version-dependent features before implementation.
