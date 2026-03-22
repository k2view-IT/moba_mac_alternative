---
phase: 03-sftp-file-browser
plan: 02
subsystem: sftp-service
tags: [sftp, subprocess, channel, file-operations, transfer]
dependency_graph:
  requires:
    - 03-01  # SFTPChannel protocol, MockSFTPChannel, model types
  provides:
    - SFTPSubprocessChannel (real /usr/bin/sftp subprocess backend)
    - SFTPBrowserService fully implemented (listDirectory, createDirectory, rename, delete, upload, download)
    - SFTPError enum
  affects:
    - MobaAlt/Services/SFTPBrowserService.swift
    - MobaAlt/Services/SFTPSubprocessChannel.swift
tech_stack:
  added:
    - Foundation.Process (/usr/bin/sftp subprocess)
    - Foundation.Pipe (stdin/stdout/stderr for sftp process)
    - AppKit.NSWorkspace (openLocally)
    - AsyncThrowingStream (upload/download progress)
  patterns:
    - socket-poll-before-connect (200ms intervals, 10s timeout)
    - readUntilPrompt (stdout accumulation until "sftp> " marker)
    - mock-skip-socket-wait (channel is MockSFTPChannel guard)
key_files:
  created:
    - MobaAlt/Services/SFTPSubprocessChannel.swift
  modified:
    - MobaAlt/Services/SFTPBrowserService.swift
    - MobaAltTests/SFTPBrowserServiceTests.swift
    - MobaAltTests/SFTPFileTransferTests.swift
    - MobaAlt.xcodeproj/project.pbxproj
decisions:
  - "SFTPSubprocessChannel uses interactive mode (no -b flag) with readUntilPrompt() for per-command responses; simpler than one-process-per-command"
  - "waitForSocket() skipped entirely for MockSFTPChannel via channel is MockSFTPChannel guard in connect() — avoids 10s test delays without protocol changes"
  - "upload/download progress uses single-shot polling (local file size or immediate completion) rather than sftp verbose output parsing — simpler and more robust"
  - "delete(at:) in MockSFTPChannel records lastCommand as 'rm <path>' matching test assertions; SFTPSubprocessChannel also sends 'rm'"
metrics:
  duration: "4 minutes"
  completed_date: "2026-03-22"
  tasks_completed: 2
  files_changed: 5
---

# Phase 3 Plan 2: SFTP Subprocess Backend and Full Service Implementation Summary

Real sftp subprocess channel over SSH ControlMaster socket with socket-polling race-condition guard, ls -la output parser, and AsyncThrowingStream upload/download — all 17 SFTP tests pass.

## Tasks Completed

### Task 1: SFTPSubprocessChannel — real /usr/bin/sftp subprocess backend

Created `MobaAlt/Services/SFTPSubprocessChannel.swift` as an internal `final class SFTPSubprocessChannel: SFTPChannel`.

Key implementation decisions:
- Uses `/usr/bin/sftp` in interactive (non-batch) mode without `-b` flag, allowing `readUntilPrompt()` to detect the `sftp> ` marker after each command
- `readUntilPrompt(timeout:)` accumulates stdout bytes in `stdoutBuffer` at 50ms polling intervals until the prompt appears
- `parseLsLine(_:basePath:)` is `internal` (not private) so tests can call it directly for unit-testing the parser
- Handles both `HH:mm` (current year) and `YYYY` date formats from `ls -la` output
- `SFTPError` enum added with `socketTimeout`, `connectionFailed`, `commandFailed` cases

Updated `SFTPBrowserService.swift`:
- Replaced all `fatalError("Not yet implemented")` bodies with real channel delegation
- Added `showHidden: Bool = false` with dotfile filtering in `listDirectory`
- Added directories-first, then alphabetical sorting in `listDirectory`
- Added `connect()` that skips socket wait for MockSFTPChannel, otherwise polls via `waitForSocket()`
- `waitForSocket(_ path:timeout:)` polls `FileManager.fileExists` at 200ms intervals up to 10s, throws `SFTPError.socketTimeout` on expiry
- Added production `convenience init(sessionId:config:)` that creates a real `SFTPSubprocessChannel`

### Task 2: Wire upload and download into SFTPBrowserService + TransferTask queue

Implemented in the same `SFTPBrowserService.swift` update:
- `upload(localURL:toRemotePath:)` — creates a `TransferTask(.upload)`, issues `put` via channel.send(), yields one `TransferProgress(1.0)` event, marks `.completed`
- `download(remotePath:toLocalURL:)` — creates a `TransferTask(.download)`, issues `get`, polls local file size vs remote size, marks `.completed`
- `openLocally(item:)` — downloads to `/tmp/mobaalt-downloads/` and opens with `NSWorkspace.shared.open`
- Both methods return `AsyncThrowingStream<TransferProgress, Error>` and update `service.transfers`

## Test Results

```
✔ Test run with 69 tests in 19 suites passed after 0.561 seconds.
** TEST SUCCEEDED **
```

SFTP-specific:
- `SFTPBrowserServiceTests`: 12 tests pass (connect, failure propagation, list with dotfile filtering, sort, createDirectory, rename, delete, parseLsLine variants)
- `SFTPFileTransferTests`: 5 tests pass (upload/download task creation, progress tracking, simultaneous transfers)

## Verification

```
grep -n "usr/bin/sftp" MobaAlt/Services/SFTPSubprocessChannel.swift
# 24: doc comment
# 60: process.executableURL = URL(fileURLWithPath: "/usr/bin/sftp")

grep -n "waitForSocket\|200\|socketTimeout" MobaAlt/Services/SFTPBrowserService.swift
# 115: try await waitForSocket(socketPath)
# 303-318: waitForSocket() with 200ms poll and socketTimeout throw
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] connect() MockSFTPChannel 10s test delay**
- **Found during:** Task 1 test run (all tests took 10s each due to socket poll timeout)
- **Issue:** `waitForSocket()` looped for 10 full seconds for MockSFTPChannel because no socket file exists in tests
- **Fix:** Added `if !(channel is MockSFTPChannel)` guard in `connect()` to skip socket wait entirely for test channels; `waitForSocket()` itself simplified to always throw on timeout (no duplicate guard)
- **Files modified:** `MobaAlt/Services/SFTPBrowserService.swift`
- **Commit:** c308c06

**2. [Rule 1 - Bug] NSWorkspace import missing**
- **Found during:** First build attempt
- **Issue:** `openLocally()` references `NSWorkspace` but `import AppKit` was missing
- **Fix:** Added `import AppKit` to SFTPBrowserService.swift
- **Files modified:** `MobaAlt/Services/SFTPBrowserService.swift`
- **Commit:** 2534be2

**3. [Rule 2 - Enhancement] MockSFTPChannel.delete records "rm" not "delete"**
- **Found during:** Implementing testDeleteCalled
- **Issue:** Original MockSFTPChannel stub recorded `"delete \(path)"` but the plan spec and tests expect `"rm \(path)"` to match sftp protocol
- **Fix:** Updated `MockSFTPChannel.delete(at:)` to record `"rm \(path)"` for consistency with SFTPSubprocessChannel behavior
- **Files modified:** `MobaAlt/Services/SFTPBrowserService.swift`
- **Commit:** 2534be2

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 2534be2 | feat | SFTPSubprocessChannel + fully implemented SFTPBrowserService |
| c308c06 | test | Replace all TODO stubs with passing assertions |

## Self-Check: PASSED

- `MobaAlt/Services/SFTPSubprocessChannel.swift` — FOUND
- `MobaAlt/Services/SFTPBrowserService.swift` — FOUND (min_lines: 120, actual: ~320)
- Commits 2534be2, c308c06 — VERIFIED
- 69/69 tests pass — VERIFIED
