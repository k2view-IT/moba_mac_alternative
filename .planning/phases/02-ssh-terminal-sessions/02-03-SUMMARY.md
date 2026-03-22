---
phase: 02-ssh-terminal-sessions
plan: 03
subsystem: ssh
tags: [ssh, swiftterm, terminal, keypair, logging, tabmanager, tdd]

# Dependency graph
requires:
  - phase: 02-01
    provides: SSHConfig with portForwardingRules, PortForwardingRule model
  - phase: 02-02
    provides: KeyVaultManager actor for storing SSH private key data

provides:
  - SSHArgumentBuilder: pure struct, converts SSHConfig -> argv for /usr/bin/ssh
  - TabManager: @Observable @MainActor class managing open SSH session tabs
  - SSHConnection: @Observable @MainActor wrapper around LocalProcessTerminalView
  - SessionLogWriter: actor writing terminal output bytes to log files
  - SSHKeyGenerator: service shelling out to /usr/bin/ssh-keygen for ed25519 keys

affects:
  - 02-04 (UI layer that embeds LocalProcessTerminalView and binds to TabManager)
  - 02-05 (SFTP uses ControlMaster socket path from SSHArgumentBuilder.controlPath)
  - 02-06 (port-forward display reads TabManager.activeConnections)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SSHArgumentBuilder: pure static struct (no state) for argv construction"
    - "@Observable @MainActor for UI-observable classes (TabManager, SSHConnection)"
    - "Actor for thread-safe file I/O (SessionLogWriter)"
    - "Process shelling out to /usr/bin/ssh-keygen for OpenSSH-format key generation"
    - "ControlMaster socket path: /tmp/mobaalt-{8charUUID}.sock stays under 104-char macOS limit"
    - "TDD: write failing tests first (RED), implement to pass (GREEN)"

key-files:
  created:
    - MobaAlt/Utilities/SSHArgumentBuilder.swift
    - MobaAlt/Services/TabManager.swift
    - MobaAlt/Services/SSHConnection.swift
    - MobaAlt/Services/SessionLogWriter.swift
    - MobaAlt/Services/SSHKeyGenerator.swift
  modified:
    - MobaAltTests/SSHArgumentBuilderTests.swift
    - MobaAltTests/TabManagerTests.swift
    - MobaAltTests/SSHConnectionTests.swift
    - MobaAltTests/SessionLogWriterTests.swift
    - MobaAltTests/SSHKeyGeneratorTests.swift
    - MobaAlt.xcodeproj/project.pbxproj
    - project.yml

key-decisions:
  - "SSHConnection sets processDelegate (not delegate) on LocalProcessTerminalView to avoid breaking SwiftTerm internal TerminalViewDelegate wiring"
  - "SSHKeyGenerator uses Task.detached for Process.run() to avoid blocking actor context; defer guarantees temp file cleanup even on error"
  - "SSHArgumentBuilder passes sessionId separately from SSHConfig because ControlMaster path needs a unique ID but SSHConfig has no sessionId field"
  - "TabManager.closeTab calls connection.terminate() before removing from array to ensure SSH process is killed before reference is dropped"
  - "SessionLogWriter uses FileHandle.seekToEnd() on init so appending to existing log files is safe"

patterns-established:
  - "Pattern: Service actors/classes go in MobaAlt/Services/, pure helpers in MobaAlt/Utilities/"
  - "Pattern: @MainActor on SSHConnection and TabManager because they interact with AppKit views and SwiftUI observation"
  - "Pattern: KeyVaultManager received as a parameter (not injected globally) to enable test isolation"

requirements-completed: [SSH-01, SSH-03, SSH-04, SSH-05, SSH-06, SSH-07, TERM-02, TERM-03, TERM-04]

# Metrics
duration: 6min
completed: 2026-03-22
---

# Phase 2 Plan 3: SSH Core Services Summary

**SSHArgumentBuilder (argv builder), TabManager (tab lifecycle), SSHConnection (SwiftTerm wrapper), SessionLogWriter (file actor), and SSHKeyGenerator (ssh-keygen subprocess) fully implemented with TDD — 21 tests passing GREEN**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-03-22T10:38:50Z
- **Completed:** 2026-03-22T10:44:40Z
- **Tasks:** 2 (both TDD)
- **Files modified:** 12

## Accomplishments

- SSHArgumentBuilder pure struct with full argv coverage: port, username, auth method, agent/X11 forwarding, port forwarding rules (-L/-R/-D), ControlMaster flags; socket path always under 104 chars
- TabManager @Observable @MainActor class with openTab/closeTab/activateTab and activeConnections for SSH-06 port-forward enumeration
- SSHConnection properly sets processDelegate (not delegate) on LocalProcessTerminalView to avoid breaking SwiftTerm's internal wiring; @MainActor-safe lifecycle
- SessionLogWriter actor safely writes ArraySlice<UInt8> to FileHandle, closes cleanly; log directory auto-created
- SSHKeyGenerator shells out to /usr/bin/ssh-keygen with empty passphrase, reads both key files, stores private key in vault, and uses defer to guarantee temp file cleanup

## Task Commits

1. **Task 1: SSHArgumentBuilder (TDD)** - `31b9607` (feat)
2. **Task 2: Services (TDD)** - `a40c82a` (feat)

## Files Created/Modified

- `MobaAlt/Utilities/SSHArgumentBuilder.swift` - Pure static struct: build(from:sessionId:), controlPath(for:), environment()
- `MobaAlt/Services/TabManager.swift` - @Observable @MainActor tab lifecycle manager
- `MobaAlt/Services/SSHConnection.swift` - @Observable @MainActor SwiftTerm LocalProcessTerminalView wrapper
- `MobaAlt/Services/SessionLogWriter.swift` - Actor writing terminal bytes to log file via FileHandle
- `MobaAlt/Services/SSHKeyGenerator.swift` - ssh-keygen subprocess with vault integration and temp file cleanup
- `MobaAltTests/SSHArgumentBuilderTests.swift` - 14 tests (basic, port, username, auth, forwarding, ControlMaster, environment)
- `MobaAltTests/TabManagerTests.swift` - 4 tests (open, close, activate, activeConnections)
- `MobaAltTests/SSHConnectionTests.swift` - 1 test (environment via SSHArgumentBuilder)
- `MobaAltTests/SessionLogWriterTests.swift` - 1 test (writes bytes to temp file, verifies data)
- `MobaAltTests/SSHKeyGeneratorTests.swift` - 1 test (integration: generates key, stores in vault, no temp files left)

## Decisions Made

- **SSHConnection uses processDelegate not delegate**: LocalProcessTerminalView's internal TerminalViewDelegate is consumed by its own implementation; overriding it would break PTY I/O. The public processDelegate proxy is the correct integration point.
- **Task.detached for ssh-keygen Process**: Actor isolation prevents blocking a Swift actor context with Process.waitUntilExit(). Detached task runs synchronously on a non-actor thread.
- **sessionId passed separately to build()**: SSHConfig is a data model without session identity; the UUID used for ControlMaster socket uniqueness comes from the session layer (TabManager), not the config itself.
- **defer for temp file cleanup in SSHKeyGenerator**: Guarantees cleanup even if reading key data throws, preventing /tmp accumulation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `TerminalViewWrapperTests.testMakeNSViewReturnsNonNil` is a pre-existing stub from plan 02-01, scaffolded for plan 02-04 (UI layer). It was already failing before this plan and is not a regression. Out-of-scope per deviation rule boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 02-04 (TerminalView UI) can now embed LocalProcessTerminalView using SSHConnection and bind to TabManager
- 02-05 (SFTP) can use SSHArgumentBuilder.controlPath(for:) to find the ControlMaster socket for an active session
- 02-06 (Port Forward display) can read TabManager.activeConnections to enumerate live sessions and their forwarding rules

---
*Phase: 02-ssh-terminal-sessions*
*Completed: 2026-03-22*
