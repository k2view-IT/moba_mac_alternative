# MobaXterm Mac Alternative

## What This Is

A native macOS app for IT and DevOps professionals that replicates the core MobaXterm experience on Mac. It provides a unified session manager for SSH, RDP, and VNC connections in a tabbed interface, with folder-organized session storage, a built-in terminal emulator, SFTP file browser, and secure credential storage. Packaged as a DMG for easy distribution to coworkers.

## Core Value

All remote connections (SSH, RDP, VNC) managed in one place with tabbed sessions, organized folders, and secure credentials — so IT/DevOps teams never need to juggle multiple disconnected tools on Mac.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can create and save SSH sessions with hostname, port, user, auth method
- [ ] User can connect via SSH in a built-in terminal tab
- [ ] SSH sessions support X11 forwarding (via XQuartz, auto-detected on launch)
- [ ] App checks for XQuartz on startup and guides installation if missing
- [ ] User can create and save RDP sessions (leverages macOS built-in Microsoft Remote Desktop or system RDP)
- [ ] User can create and save VNC sessions (leverages macOS built-in Screen Sharing)
- [ ] Each connection opens in its own tab within the app
- [ ] User can organize sessions into folders (hierarchical)
- [ ] User can search/filter saved sessions
- [ ] Built-in SFTP file browser panel alongside SSH terminal sessions
- [ ] Passwords stored in macOS Keychain
- [ ] SSH private keys managed in an encrypted local vault
- [ ] App packaged as a DMG installer for distribution
- [ ] Multi-tab view with ability to split or switch between active sessions

### Out of Scope

- iOS / iPhone version — desktop tool only
- Cloud sync of sessions — local storage only for v1
- Serial/telnet connections — not in initial scope
- Built-in text editor — use terminal editors (vim/nano)
- App Store distribution — DMG direct distribution only

## Context

- Target users: IT and DevOps personnel, all technically proficient (comfortable with XQuartz, SSH keys, etc.)
- Current workflow: Users run MobaXterm on Windows; this replaces it on Mac
- Mac built-in tools to leverage: macOS SSH client, Screen Sharing (VNC), Microsoft Remote Desktop app or built-in RDP, macOS Keychain
- XQuartz required for X11 forwarding; app should detect its absence and provide guided install steps
- Distribution: DMG shared with coworkers — no App Store signing requirements initially

## Constraints

- **Platform**: macOS only — native Swift/SwiftUI app
- **X11**: Depends on XQuartz install; app must degrade gracefully if absent (disable X11 option, show install guide)
- **Terminal emulator**: Must run inside the app (not spawn external Terminal.app) — requires either a custom terminal view or embedding a library like SwiftTerm
- **RDP/VNC**: Will launch/embed macOS system tools (Microsoft Remote Desktop, Screen Sharing) rather than implementing protocols from scratch
- **Credentials**: macOS Keychain for passwords + AES-encrypted local file for SSH key vault

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native Swift/SwiftUI over Electron | Performance, native feel, easier DMG packaging, smaller bundle | — Pending |
| Use SwiftTerm for terminal emulator | Battle-tested Swift terminal library, avoids building VT100 from scratch | — Pending |
| Delegate RDP/VNC to system apps | Avoids reimplementing complex protocols; RDP/VNC sessions open in system app | — Pending |
| XQuartz for X11 (not bundled) | Keeps DMG small; IT users can install once; app guides them | — Pending |

---
*Last updated: 2026-03-19 after initialization*
