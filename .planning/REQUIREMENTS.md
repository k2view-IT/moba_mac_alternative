# Requirements: MobaXterm Mac Alternative

**Defined:** 2026-03-19
**Core Value:** All remote connections (SSH, RDP, VNC) managed in one place with tabbed sessions, organized folders, and secure credentials — so IT/DevOps teams never need to juggle multiple disconnected tools on Mac.

## v1 Requirements

### Session Management

- [ ] **SESS-01**: User can create a saved session (SSH, RDP, or VNC) with name, hostname, port, username, and auth method
- [ ] **SESS-02**: User can organize sessions into nested folders in the sidebar
- [ ] **SESS-03**: User can search and filter saved sessions by name or hostname
- [ ] **SESS-04**: User can import sessions from a MobaXterm .mxtsessions export file
- [ ] **SESS-05**: User can export all sessions to a portable file for backup or sharing with coworkers

### SSH

- [ ] **SSH-01**: User can connect to an SSH host and get a terminal session in a new tab
- [ ] **SSH-02**: SSH sessions support both password and SSH key authentication
- [ ] **SSH-03**: SSH respects the user's existing ~/.ssh/config and known_hosts files
- [ ] **SSH-04**: User can enable SSH agent forwarding per session (ForwardAgent)
- [ ] **SSH-05**: User can configure port forwarding rules per session (local, remote, dynamic)
- [ ] **SSH-06**: User can view and manage active port forwarding tunnels while connected
- [ ] **SSH-07**: User can generate new SSH key pairs from within the app

### Terminal

- [ ] **TERM-01**: Terminal emulator runs inside the app in a tab (no external Terminal.app)
- [ ] **TERM-02**: Multiple sessions open simultaneously in tabs with easy switching
- [ ] **TERM-03**: Terminal supports full color output, scrollback buffer, resize, and ANSI sequences
- [ ] **TERM-04**: Terminal session output can be automatically logged to a file per session
- [ ] **TERM-05**: User can save reusable command snippets and execute them in the active session

### X11 Forwarding

- [ ] **X11-01**: App detects whether XQuartz is installed on startup and shows a guided install prompt if missing
- [ ] **X11-02**: User can enable X11 forwarding per SSH session when XQuartz is available

### SFTP

- [ ] **SFTP-01**: An SFTP file browser panel opens automatically alongside every SSH terminal session
- [ ] **SFTP-02**: User can browse the remote directory tree in the SFTP panel
- [ ] **SFTP-03**: User can upload files to the remote host via drag-and-drop into the SFTP panel
- [ ] **SFTP-04**: User can download files from the remote host via drag-and-drop or context menu
- [ ] **SFTP-05**: User can create, rename, and delete files and folders via the SFTP panel

### RDP

- [ ] **RDP-01**: User can create and save RDP sessions with hostname, port, and username
- [ ] **RDP-02**: User can launch an RDP session (opens Microsoft Remote Desktop via URL scheme or .rdp file)

### VNC

- [ ] **VNC-01**: User can create and save VNC sessions with hostname, port, and optional password
- [ ] **VNC-02**: User can launch a VNC session (opens macOS Screen Sharing via vnc:// URL scheme)

### Credentials

- [ ] **CRED-01**: SSH and RDP/VNC passwords are stored securely in macOS Keychain
- [ ] **CRED-02**: SSH private keys are stored in an AES-GCM encrypted local vault file
- [ ] **CRED-03**: User can unlock the SSH key vault with a master password
- [ ] **CRED-04**: User can add, view, and remove stored credentials per session

### Distribution

- [ ] **DIST-01**: App is distributed as a notarized, code-signed DMG installer
- [ ] **DIST-02**: App requires macOS 14 (Sonoma) as the minimum deployment target
- [ ] **DIST-03**: App uses Hardened Runtime (without App Sandbox) to allow SSH process spawning and Keychain access

## v2 Requirements

### Terminal Advanced

- **TERM-V2-01**: Split panes — split a tab horizontally/vertically to run two sessions side by side
- **TERM-V2-02**: Broadcast / multi-exec — type once and send input to multiple sessions simultaneously

### Jump Hosts

- **SSH-V2-01**: Jump host / bastion support with UI for configuring ProxyJump chains

### Embedded Viewers

- **RDP-V2-01**: Embedded RDP viewer inside the app (no external app required)
- **VNC-V2-01**: Embedded VNC viewer inside the app (no external app required)

### Team Features

- **TEAM-V2-01**: Cloud sync or shared session repository for team-wide session sharing

### Notifications

- **NOTIF-V2-01**: Alert when a long-running SSH command completes (bell / system notification)

## Out of Scope

| Feature | Reason |
|---------|--------|
| iOS / iPadOS version | Desktop IT workflow only; no mobile use case identified |
| App Store distribution | Requires App Sandbox which blocks SSH process spawning; DMG is preferred |
| Serial / Telnet connections | Not in user's workflow |
| Built-in text editor | Terminal editors (vim/nano) are standard for target audience |
| Cloud sync of sessions (v1) | Local storage sufficient for v1; team sharing via export/import |
| FreeRDP / LibVNC embedding (v1) | Enormous scope; URL scheme delegation works fine for v1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SESS-01 | Phase 1 | Pending |
| SESS-02 | Phase 1 | Pending |
| SESS-03 | Phase 1 | Pending |
| SESS-04 | Phase 1 | Pending |
| SESS-05 | Phase 1 | Pending |
| DIST-01 | Phase 1 | Pending |
| DIST-02 | Phase 1 | Pending |
| DIST-03 | Phase 1 | Pending |
| SSH-01 | Phase 2 | Pending |
| SSH-02 | Phase 2 | Pending |
| SSH-03 | Phase 2 | Pending |
| SSH-04 | Phase 2 | Pending |
| SSH-05 | Phase 2 | Pending |
| SSH-06 | Phase 2 | Pending |
| SSH-07 | Phase 2 | Pending |
| TERM-01 | Phase 2 | Pending |
| TERM-02 | Phase 2 | Pending |
| TERM-03 | Phase 2 | Pending |
| TERM-04 | Phase 2 | Pending |
| TERM-05 | Phase 2 | Pending |
| CRED-01 | Phase 2 | Pending |
| CRED-02 | Phase 2 | Pending |
| CRED-03 | Phase 2 | Pending |
| CRED-04 | Phase 2 | Pending |
| SFTP-01 | Phase 3 | Pending |
| SFTP-02 | Phase 3 | Pending |
| SFTP-03 | Phase 3 | Pending |
| SFTP-04 | Phase 3 | Pending |
| SFTP-05 | Phase 3 | Pending |
| RDP-01 | Phase 4 | Pending |
| RDP-02 | Phase 4 | Pending |
| VNC-01 | Phase 4 | Pending |
| VNC-02 | Phase 4 | Pending |
| X11-01 | Phase 4 | Pending |
| X11-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0

---
*Requirements defined: 2026-03-19*
*Last updated: 2026-03-19 after roadmap creation*
