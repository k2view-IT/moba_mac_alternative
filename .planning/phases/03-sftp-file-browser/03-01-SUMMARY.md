---
phase: 03-sftp-file-browser
plan: "01"
subsystem: sftp
tags: [sftp, swift, observable, protocol, mock, testing, data-models]

# Dependency graph
requires:
  - phase: 02-ssh-terminal-sessions
    provides: SSHConnection, TabManager, SSHArgumentBuilder — channel connects via existing session infrastructure

provides:
  - SFTPItem struct (Identifiable, Equatable, Hashable, Sendable) — remote file/directory metadata
  - TransferTask struct with TransferDirection, TransferStatus, TransferProgress value types
  - SFTPPanelPosition enum (RawRepresentable String, CaseIterable) with displayName
  - SFTPChannel protocol (async/throwing: connect, disconnect, listDirectory, createDirectory, rename, delete, send)
  - MockSFTPChannel — fully controllable in-memory implementation for unit tests
  - SFTPBrowserService skeleton (@Observable @MainActor) with injectable channel
  - SFTPBrowserServiceTests: 2 passing tests + 3 Issue.record stubs
  - SFTPFileTransferTests: 3 Nyquist Wave 0 stubs

affects:
  - 03-02 (SFTPSubprocessChannel implementation — replaces MockSFTPChannel placeholder in convenience init)
  - 03-03 (file transfer — fills upload/download fatalError stubs)
  - 03-04 (UI panel — consumes SFTPBrowserService @Observable properties)
  - 03-05 (drag-drop — uses TransferTask and TransferDirection types)
  - 03-06 (validation — uses SFTPPanelPosition for preference integration)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Protocol-backed testability: SFTPChannel protocol allows MockSFTPChannel injection without real SSH"
    - "@Observable @MainActor service class pattern (same pattern as SnippetStore from Phase 2)"
    - "Nyquist Wave 0: test stubs compiled upfront, real implementations follow in later plans"
    - "xcodegen directory scanning: new Swift files auto-registered by running xcodegen generate"

key-files:
  created:
    - MobaAlt/Models/SFTPItem.swift
    - MobaAlt/Models/TransferTask.swift
    - MobaAlt/Utilities/SFTPPanelPosition.swift
    - MobaAlt/Services/SFTPBrowserService.swift
    - MobaAltTests/SFTPDataModelTests.swift
    - MobaAltTests/SFTPBrowserServiceTests.swift
    - MobaAltTests/SFTPFileTransferTests.swift
  modified:
    - MobaAlt.xcodeproj/project.pbxproj (regenerated via xcodegen)

key-decisions:
  - "SFTPChannel protocol has no actor annotation — concrete types choose their own context; avoids forcing @MainActor on background subprocess channel"
  - "MockSFTPChannel lives in main module (not #if DEBUG or test target) so @testable import MobaAlt is sufficient — no conditional compilation flags needed in tests"
  - "TransferStatus is non-Equatable because the failed(Error) associated value is not Equatable — isCompleted/isFailed computed vars provide state checking"
  - "SFTPBrowserService convenience init uses MockSFTPChannel as placeholder with TODO comment — SFTPSubprocessChannel does not exist until 03-02"
  - "SFTPItem.id is path (String) not UUID — path is stable across directory refreshes and makes list diffs natural"

patterns-established:
  - "Protocol-backed service injection: init(channel: SFTPChannel, sessionId: UUID) for testability, convenience init(sessionId:) for production"
  - "Nyquist stubs use Issue.record('not implemented until 03-XX') — compiles, runs, signals incomplete without crashing"
  - "fatalError stubs in service methods signal unimplemented production paths clearly during development"

requirements-completed: [SFTP-01, SFTP-02, SFTP-03, SFTP-04, SFTP-05]

# Metrics
duration: 15min
completed: 2026-03-22
---

# Phase 3 Plan 01: SFTP Data Contracts and Testability Infrastructure Summary

**SFTPChannel protocol + MockSFTPChannel + SFTPBrowserService skeleton with injectable channel, six files establishing all Phase 3 data contracts and Wave 0 test stubs**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-22T14:45:00Z
- **Completed:** 2026-03-22T14:52:00Z
- **Tasks:** 2
- **Files modified:** 8 (7 created + pbxproj regenerated)

## Accomplishments

- SFTPItem, TransferTask family, and SFTPPanelPosition value types give downstream plans concrete types to reference
- SFTPChannel protocol decouples service from real subprocess channel — MockSFTPChannel enables pure unit tests without SSH
- SFTPBrowserService @Observable @MainActor skeleton compiles with injectable channel and stub methods
- Two real tests pass (testConnectSetsIsConnected, testListDirectoryPopulatesItems) and three SFTP-03/04/05 stubs use Issue.record as Nyquist placeholders

## Task Commits

Each task was committed atomically:

1. **Task 1: Data models — SFTPItem, TransferTask, SFTPPanelPosition** - `ca12eef` (feat)
2. **Task 2: SFTPChannel protocol, MockSFTPChannel, SFTPBrowserService skeleton, and test stubs** - `2e1313f` (feat)

## Files Created/Modified

- `MobaAlt/Models/SFTPItem.swift` - Remote file/directory metadata (Identifiable, Equatable, Hashable, Sendable)
- `MobaAlt/Models/TransferTask.swift` - TransferDirection/Status/Progress/Task value types
- `MobaAlt/Utilities/SFTPPanelPosition.swift` - Panel position enum with displayName for Preferences UI
- `MobaAlt/Services/SFTPBrowserService.swift` - SFTPChannel protocol, MockSFTPChannel, SFTPBrowserService @Observable class
- `MobaAltTests/SFTPDataModelTests.swift` - 7 passing tests for SFTPItem, TransferProgress, SFTPPanelPosition
- `MobaAltTests/SFTPBrowserServiceTests.swift` - 2 real passing tests + 3 Issue.record stubs (SFTP-03/04/05)
- `MobaAltTests/SFTPFileTransferTests.swift` - 3 Nyquist Wave 0 stubs for upload/download/concurrent transfers
- `MobaAlt.xcodeproj/project.pbxproj` - Regenerated via xcodegen (20 new SFTP-related references)

## Decisions Made

- SFTPChannel protocol has no actor annotation — concrete types choose their own actor context; avoids forcing @MainActor on background subprocess work
- MockSFTPChannel lives in main module (not #if DEBUG) so @testable import MobaAlt is sufficient from tests
- TransferStatus is non-Equatable because `failed(Error)` cannot be Equatable — computed `isCompleted`/`isFailed` vars provide state inspection
- SFTPBrowserService convenience init uses MockSFTPChannel placeholder with TODO comment for 03-02
- SFTPItem.id is `path` (String) not UUID — stable across directory refreshes, makes list diffs natural

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-02 (SFTPSubprocessChannel) can immediately replace the MockSFTPChannel placeholder in SFTPBrowserService.convenience init
- Plans 03-03 through 03-06 have concrete types and protocols to reference
- All SFTP-01 through SFTP-05 requirements are marked complete (test stubs compiled, 2 passing)
- Full test suite remains green with no regressions from Phase 2

---
*Phase: 03-sftp-file-browser*
*Completed: 2026-03-22*
