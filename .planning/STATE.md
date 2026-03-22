---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: completed
stopped_at: "Completed 02-03-PLAN.md: SSH core services (SSHArgumentBuilder, TabManager, SSHConnection, SessionLogWriter, SSHKeyGenerator)"
last_updated: "2026-03-22T10:52:17.733Z"
last_activity: 2026-03-20 -- Phase 1 human-verify approved; all 3 plans complete
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 9
  completed_plans: 6
  percent: 25
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-19)

**Core value:** All remote connections (SSH, RDP, VNC) managed in one place with tabbed sessions, organized folders, and secure credentials -- so IT/DevOps teams never need to juggle multiple disconnected tools on Mac.
**Current focus:** Phase 1 - App Foundation and Session Management

## Current Position

Phase: 1 of 4 (App Foundation and Session Management) -- COMPLETE
Plan: 3 of 3 in current phase (all complete)
Status: Phase 1 complete. Ready to begin Phase 2.
Last activity: 2026-03-20 -- Phase 1 human-verify approved; all 3 plans complete

Progress: [██░░░░░░░░] 25%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 01-app-foundation-and-session-management P01 | 7 | 2 tasks | 19 files |
| Phase 01-app-foundation-and-session-management P02 | 5 | 2 tasks | 13 files |
| Phase 01-app-foundation-and-session-management P03 | 56 | 2 tasks | 15 files |
| Phase 02-ssh-terminal-sessions P01 | 5 | 2 tasks | 13 files |
| Phase 02-ssh-terminal-sessions P02 | 7 | 2 tasks | 5 files |
| Phase 02-ssh-terminal-sessions P03 | 13 | 2 tasks | 12 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Merged Credentials (Phase 3 in research) into SSH Terminal phase -- credentials are needed for SSH auth and separating them adds a phase boundary without delivering user value
- Roadmap: 4 phases (coarse granularity) derived from 5-phase research recommendation by compressing credentials into SSH phase
- [Phase 01]: Used xcodegen (Homebrew) to generate Xcode project from project.yml — avoids hand-editing project.pbxproj
- [Phase 01]: ConnectionProtocol uses {type,config} JSON discriminator for forward-compatibility with future protocol additions in Phases 2-4
- [Phase 01]: SessionStore exposes init(directory:) for test isolation — avoids polluting Application Support during unit test runs
- [Phase 01]: Moved ContentView to Views/AppShell/ to co-locate with SidebarView; old Views/ContentView.swift emptied to avoid duplicate type
- [Phase 01]: FolderDropDelegate takes targetFolderId: UUID? (nil=root) so same delegate reused for folder row drops and sidebar background drop zone
- [Phase 01]: App.init() async startup moved to .task{} on WindowGroup — App structs are value types in Swift 5.9, escaping Task closures in init() captured a copy of @State, silently breaking load/save
- [Phase 01]: ExportDialogSheet built in Phase 1 with full checkbox tree, format picker, and NSSavePanel — write logic deferred to 01-03, but dialog UX complete so context menu entries are not deceptive placeholders
- [Phase 01]: Removed custom sidebar.left ToolbarItem — NavigationSplitView already provides its own sidebar toggle button; adding a second caused a duplicate in the toolbar
- [Phase 01-app-foundation-and-session-management]: MobaXterm RDP type code is 1 (not 4 as documented) — parser accepts both 1 and 4 for forward-compatibility
- [Phase 01-app-foundation-and-session-management]: ImportWizardSheet uses sheet-over-sheet pattern for conflict and summary sheets to preserve wizard state during multi-step import flow
- [Phase 02-ssh-terminal-sessions]: SwiftTerm requires Metal Toolchain component — downloaded via xcodebuild -downloadComponent MetalToolchain before build succeeded
- [Phase 02-ssh-terminal-sessions]: SSHConfig backward-compat: custom init(from:) using decodeIfPresent for portForwardingRules so old session JSON without the field decodes without error
- [Phase 02-ssh-terminal-sessions]: KeychainManager uses init(service:) overload with unique test service identifier to isolate test Keychain items from production items
- [Phase 02-ssh-terminal-sessions]: VaultManager wrong-password detection uses CryptoKitError catch on AES.GCM.open (tag mismatch) rather than a separate verification record — simpler and equally secure
- [Phase 02-ssh-terminal-sessions]: Vault salt (32 random bytes) is NOT secret — stored in plaintext alongside vault; only the HKDF-derived key is secret
- [Phase 02-ssh-terminal-sessions]: SSHConnection uses processDelegate (not delegate) to avoid breaking SwiftTerm's internal TerminalViewDelegate wiring
- [Phase 02-ssh-terminal-sessions]: SSHArgumentBuilder.build() takes sessionId separately from SSHConfig — ControlMaster socket uniqueness comes from session layer, not config model

### Pending Todos

None yet.

### Blockers/Concerns

- Research flags SwiftTerm API verification needed at Phase 2 kickoff
- Research flags libssh2 SPM wrapper evaluation needed at Phase 3 kickoff
- Keychain signing identity must be locked during Phase 2 credential work (affects all future credential access)

## Session Continuity

Last session: 2026-03-22T10:52:17.731Z
Stopped at: Completed 02-03-PLAN.md: SSH core services (SSHArgumentBuilder, TabManager, SSHConnection, SessionLogWriter, SSHKeyGenerator)
Resume file: None
