# Roadmap: MobaXterm Mac Alternative

## Overview

This roadmap delivers a native macOS session manager for IT/DevOps teams in four phases. Phase 1 establishes the app shell, session model, and signing infrastructure -- the foundation everything else depends on. Phase 2 delivers the highest-value, highest-risk feature: SSH terminal with credentials and tabbed sessions. Phase 3 adds the SFTP file browser (the key differentiator over iTerm2), riding on the SSH ControlMaster infrastructure from Phase 2. Phase 4 completes protocol coverage with RDP, VNC, and X11 forwarding.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: App Foundation and Session Management** - Runnable app with session CRUD, folder organization, search, import/export, code signing, and DMG distribution pipeline
- [ ] **Phase 2: SSH Terminal and Credentials** - SSH connections in embedded terminal tabs with full credential management (Keychain passwords + encrypted SSH key vault)
- [ ] **Phase 3: SFTP File Browser** - Side-panel SFTP browser alongside SSH sessions with drag-and-drop file transfer
- [ ] **Phase 4: RDP, VNC, and X11 Forwarding** - RDP and VNC session launch via system apps, X11 forwarding with XQuartz detection

## Phase Details

### Phase 1: App Foundation and Session Management
**Goal**: Users can create, organize, search, and persist remote sessions in a native macOS app that is properly signed and distributable as a DMG
**Depends on**: Nothing (first phase)
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, SESS-05, DIST-01, DIST-02, DIST-03
**Success Criteria** (what must be TRUE):
  1. User can create a saved session (SSH, RDP, or VNC type) with name, hostname, port, username, and auth method, and it persists across app restarts
  2. User can organize sessions into nested folders in the sidebar and drag sessions between folders
  3. User can search saved sessions by name or hostname and see filtered results instantly
  4. User can import sessions from a MobaXterm .mxtsessions file and export all sessions to a portable file
  5. App installs from a DMG on a clean Mac (macOS 14+), launches without Gatekeeper warnings, and spawns a child process without sandbox errors (validates Hardened Runtime + code signing)
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — Xcode project, data models (SessionDefinition/SessionFolder/ConnectionProtocol), JSON persistence actor, Wave 0 test scaffolding
- [ ] 01-02-PLAN.md — App UI shell: NavigationSplitView, sidebar folder tree with drag-and-drop, session create/edit modal with Wizard mode, real-time search, Preferences
- [ ] 01-03-PLAN.md — MobaXterm .mxtsessions import wizard (tree selection, conflict resolution), three export formats, and DMG/notarization build pipeline

### Phase 2: SSH Terminal and Credentials
**Goal**: Users can securely connect to SSH hosts in an embedded terminal with tabbed sessions, using passwords from Keychain or SSH keys from an encrypted vault
**Depends on**: Phase 1
**Requirements**: SSH-01, SSH-02, SSH-03, SSH-04, SSH-05, SSH-06, SSH-07, TERM-01, TERM-02, TERM-03, TERM-04, TERM-05, CRED-01, CRED-02, CRED-03, CRED-04
**Success Criteria** (what must be TRUE):
  1. User can open an SSH connection from a saved session and interact with a remote shell in a terminal tab inside the app (not Terminal.app)
  2. Terminal correctly renders vim syntax highlighting, tmux splits, htop bar graphs, and 256-color output with working scrollback, resize, and copy/paste
  3. User can have multiple SSH sessions open simultaneously in tabs and switch between them without lag or lost state
  4. User can authenticate with password (stored in macOS Keychain) or SSH key (from encrypted vault unlocked with master password), and can add/view/remove credentials per session
  5. User can configure agent forwarding, port forwarding rules (local/remote/dynamic), and view active tunnels while connected
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD
- [ ] 02-03: TBD

### Phase 3: SFTP File Browser
**Goal**: Users can browse and transfer files on remote hosts through a visual SFTP panel that opens alongside every SSH terminal session
**Depends on**: Phase 2
**Requirements**: SFTP-01, SFTP-02, SFTP-03, SFTP-04, SFTP-05
**Success Criteria** (what must be TRUE):
  1. An SFTP file browser panel opens automatically alongside every SSH terminal session without requiring separate authentication
  2. User can browse the remote directory tree, and create, rename, and delete files and folders via the SFTP panel
  3. User can upload files by dragging from Finder into the SFTP panel and download files via drag-and-drop or context menu
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: RDP, VNC, and X11 Forwarding
**Goal**: Users can manage and launch RDP and VNC sessions from the app, and enable X11 forwarding on SSH sessions when XQuartz is available
**Depends on**: Phase 1 (session model), Phase 2 (SSH for X11)
**Requirements**: RDP-01, RDP-02, VNC-01, VNC-02, X11-01, X11-02
**Success Criteria** (what must be TRUE):
  1. User can create and save RDP sessions and launch them (opens Microsoft Remote Desktop via URL scheme or .rdp file)
  2. User can create and save VNC sessions and launch them (opens macOS Screen Sharing via vnc:// URL)
  3. App detects whether XQuartz is installed on startup and shows a guided install prompt if missing; user can enable X11 forwarding per SSH session when XQuartz is present
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Foundation and Session Management | 0/3 | Ready to execute | - |
| 2. SSH Terminal and Credentials | 0/3 | Not started | - |
| 3. SFTP File Browser | 0/2 | Not started | - |
| 4. RDP, VNC, and X11 Forwarding | 0/2 | Not started | - |
