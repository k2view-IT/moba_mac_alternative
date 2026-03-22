---
phase: 03-sftp-file-browser
plan: 03
subsystem: ui
tags: [sftp, tabmanager, swiftui, split-view, observable, tdd]

requires:
  - phase: 03-sftp-file-browser/03-01
    provides: SFTPPanelPosition enum and SFTPItem model
  - phase: 03-sftp-file-browser/03-02
    provides: SFTPBrowserService with connect/disconnect/listDirectory

provides:
  - TabItem with sftpPosition and sftpService fields
  - TabManager with SFTP lifecycle (open creates service, close disconnects)
  - TabManager.setSFTPPosition(_:for:) for toolbar button
  - ContentView detail area with HSplitView/VSplitView based on sftpPosition
  - SFTP toolbar button cycling through left/right/bottom/hidden positions
  - Auto-connect: SFTPBrowserService.connect() called when SSHConnection reaches .connected

affects:
  - 03-04 (SFTPPanelView real implementation replaces ContentView stub)
  - 03-05 (transfer footer slot in SFTPPanelView)

tech-stack:
  added: []
  patterns:
    - "sftpChannelFactory closure on TabManager for test injection of MockSFTPChannel"
    - "withObservationTracking loop on @Observable SSHConnection.state for SFTP auto-connect"
    - "HSplitView/VSplitView switched via activeTab.sftpPosition in ContentView detail"

key-files:
  created: []
  modified:
    - MobaAlt/Services/TabManager.swift
    - MobaAlt/Views/AppShell/ContentView.swift
    - MobaAltTests/TabManagerTests.swift

key-decisions:
  - "Used sftpChannelFactory closure on TabManager instead of protocol injection — simpler, no extra abstraction"
  - "withObservationTracking loop in a Task for SFTP auto-connect avoids adding didConnect callback to SSHConnection"
  - "Disconnect is async (Task { await sftpService.disconnect() }) to avoid blocking closeTab on @MainActor"
  - "Private SFTPPanelView stub in ContentView.swift; plan 03-04 provides real type and removes stub"
  - "Task.yield() needed in test before connection.start() so observation Task can register first"

patterns-established:
  - "sftpChannelFactory: override in tests with { _, _ in MockSFTPChannel() } for SFTP service testability"
  - "Observation loop pattern: Task { @MainActor } + withObservationTracking + CheckedContinuation for @Observable state watching"

requirements-completed: [SFTP-01]

duration: 15min
completed: 2026-03-22
---

# Phase 3 Plan 03: TabManager SFTP Lifecycle and ContentView Split Layout Summary

**TabItem extended with sftpPosition/sftpService, ContentView detail area split into HSplitView/VSplitView driven by per-tab SFTP panel position, with auto-connect via withObservationTracking on SSHConnection state**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-22T15:02:00Z
- **Completed:** 2026-03-22T15:06:13Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- TabItem gains `sftpPosition: SFTPPanelPosition` and `sftpService: SFTPBrowserService` — per-tab SFTP state
- TabManager creates SFTPBrowserService in `openTab(for:)` via injectable `sftpChannelFactory` closure, disconnects in `closeTab(_:)`
- Auto-connect: `withObservationTracking` loop fires when `SSHConnection.state` reaches `.connected`, calls `sftpService.connect()`
- ContentView detail area replaced with `detailBody` using `HSplitView`/`VSplitView` based on `sftpPosition`
- Toolbar button cycles panel position through all four positions with SF Symbol feedback
- 4 new TabManagerTests added; all 73 tests pass

## Task Commits

1. **Task 1: Extend TabItem and TabManager with SFTP lifecycle** - `87cb29f` (feat + test TDD)
2. **Task 2: ContentView split-view refactor and SFTP position toolbar button** - `9ddd915` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `MobaAlt/Services/TabManager.swift` - TabItem extended with sftpPosition/sftpService; TabManager gains sftpChannelFactory, setSFTPPosition, auto-connect observation loop
- `MobaAlt/Views/AppShell/ContentView.swift` - detail area replaced with HSplitView/VSplitView; SFTP toolbar button; private SFTPPanelView stub
- `MobaAltTests/TabManagerTests.swift` - 4 new tests: create service, disconnect on close, setSFTPPosition, auto-connect on SSH connected

## Decisions Made

- Used `sftpChannelFactory` closure on TabManager (not a protocol) — avoids over-engineering, easy to override in tests
- `withObservationTracking` loop approach for state observation — SSHConnection is @Observable so this is the idiomatic pattern
- disconnect() called via detached `Task { await }` so `closeTab` isn't blocked by async SFTP teardown
- Private `SFTPPanelView` stub in ContentView — Plan 03-04 will create the real type and remove the stub
- `Task.yield()` in the auto-connect test before `connection.start()` ensures the observation Task registers before the state change occurs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task.yield() needed in test to let observation Task start**
- **Found during:** Task 1 (testSFTPServiceConnectsWhenSSHConnects)
- **Issue:** The observation Task is enqueued but doesn't start immediately; calling `connection.start()` before the Task runs means `withObservationTracking` never subscribes
- **Fix:** Added `await Task.yield()` in test between `openTab` and `connection.start()`
- **Files modified:** MobaAltTests/TabManagerTests.swift
- **Verification:** testSFTPServiceConnectsWhenSSHConnects passes after fix
- **Committed in:** `87cb29f` (Task 1 commit)

**2. [Rule 1 - Bug] testCloseTabDisconnectsSFTPService needed async sleep**
- **Found during:** Task 1 (testCloseTabDisconnectsSFTPService)
- **Issue:** `closeTab` schedules disconnect via `Task { await }` — test was checking `didConnect` synchronously before the Task ran
- **Fix:** Added 50ms `Task.sleep` after `closeTab` to allow async disconnect to complete
- **Files modified:** MobaAltTests/TabManagerTests.swift
- **Verification:** testCloseTabDisconnectsSFTPService passes
- **Committed in:** `87cb29f` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - test timing bugs)
**Impact on plan:** Both were test timing issues, not production code bugs. No scope creep.

## Issues Encountered

None — plan executed as specified with test timing adjustments.

## Next Phase Readiness

- 03-04 can now create the real `SFTPPanelView.swift` — the stub in ContentView must be removed at that point
- The `SFTPBrowserService` instance is available on every `TabItem.sftpService` for 03-04's views to bind to
- `setSFTPPosition(_:for:)` is callable from anywhere (toolbar, preferences)

---
*Phase: 03-sftp-file-browser*
*Completed: 2026-03-22*
