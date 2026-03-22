---
phase: 03-sftp-file-browser
plan: 05
subsystem: sftp-transfer-ux
tags: [sftp, upload, download, drag-drop, preferences, progress-footer]
dependency_graph:
  requires: [03-03, 03-04]
  provides: [SFTPTransferFooter, SFTPDropTargetView, upload-toolbar, download-save-panel, sftp-preferences]
  affects: [SFTPPanelView, SFTPFileListView, PreferencesView]
tech_stack:
  added: []
  patterns:
    - NSDraggingDestination via NSViewRepresentable overlay at opacity 0.001
    - NSOpenPanel/NSSavePanel with runModal() for synchronous file picker UX
    - @AppStorage with RawRepresentable enum for typed user defaults
    - AsyncThrowingStream progress tracking via existing upload/download service methods
key_files:
  created:
    - MobaAlt/Views/SFTP/SFTPTransferFooter.swift
    - MobaAlt/Views/SFTP/SFTPDropTargetView.swift
  modified:
    - MobaAlt/Views/SFTP/SFTPPanelView.swift
    - MobaAlt/Views/SFTP/SFTPFileListView.swift
    - MobaAlt/Views/Preferences/PreferencesView.swift
    - MobaAlt.xcodeproj/project.pbxproj
decisions:
  - NSDraggingDestination via NSView subclass (not SwiftUI .onDrop) — single code path for both in-app and cross-app Finder drops; avoids double-handling
  - batchDownloadWithPanel uses NSOpenPanel (directory chooser) rather than NSSavePanel for multi-file downloads — NSSavePanel cannot represent "save N files"
  - SFTPDropTargetNSView does not explicitly declare NSDraggingDestination — NSView already provides the protocol; explicit conformance causes a redundant-conformance compiler error on macOS 15+
metrics:
  duration_minutes: 3
  completed_date: "2026-03-22"
  tasks_completed: 2
  files_created: 2
  files_modified: 4
---

# Phase 03 Plan 05: Transfer UX — Footer, Drop Target, Upload Button, Download Dialog, Preferences Summary

Non-blocking SFTP transfer UX: Finder drag-drop upload via NSDraggingDestination overlay, upload toolbar button via NSOpenPanel, download via NSSavePanel (single and batch), live progress footer, and SFTP panel position preference with @AppStorage.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | SFTPTransferFooter, SFTPDropTargetView, Upload toolbar | 3b38f68 | SFTPTransferFooter.swift, SFTPDropTargetView.swift, SFTPPanelView.swift |
| 2 | Download via NSSavePanel and Preferences SFTP section | b97fa88 | SFTPFileListView.swift, PreferencesView.swift |

## What Was Built

### SFTPTransferFooter (new file)

Renders at the bottom of `SFTPPanelView`. Computed `activeTransfers` filters `service.transfers` to only pending/in-progress items. Single active transfer shows a 32pt bar with filename + linear `ProgressView`. Multiple transfers show a ScrollView capped at 96pt with one row per transfer and a summary line below. Observes `service.transfers` reactively via `@Observable`.

### SFTPDropTargetView (new file)

`NSViewRepresentable` wrapping `SFTPDropTargetNSView`. The NSView subclass calls `registerForDraggedTypes([.fileURL])` in its init and implements `draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation`, and `concludeDragOperation`. On successful drop, each URL is uploaded via `service.upload(localURL:toRemotePath:)` in a `Task { @MainActor in }`. A subtle accentColor overlay (15% opacity + 2pt border) appears while dragging. After drop, triggers a delayed directory refresh.

### SFTPPanelView updates

- Upload toolbar strip (above breadcrumb): `NSOpenPanel` with `allowsMultipleSelection=true`, `canChooseFiles=true`, `canChooseDirectories=true`.
- File area is now a `ZStack` with `SFTPDropTargetView` at `opacity(0.001)` and `allowsHitTesting(false)` as an overlay — clicks pass through to the list.
- Footer stub replaced with `SFTPTransferFooter(service: service)`.

### SFTPFileListView updates

- `downloadWithPanel(item:)` now uses `panel.runModal()` with `canCreateDirectories = true`.
- New `batchDownloadWithPanel()` opens `NSOpenPanel` (directory chooser) and downloads all items in `selection` into the chosen folder.
- Context menu shows "Download N Items" when `selection.count > 1`, otherwise single-file "Download".

### PreferencesView updates

- Added `@AppStorage("sftpDefaultPosition") private var sftpDefaultPosition: SFTPPanelPosition = .left`.
- New "SFTP Panel" section with a segmented `Picker` over `SFTPPanelPosition.allCases` and a caption hint.
- Frame height increased from 200pt to 280pt to accommodate the extra section.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed redundant NSDraggingDestination conformance**
- **Found during:** Task 1, first build attempt
- **Issue:** `class SFTPDropTargetNSView: NSView, NSDraggingDestination` produces `error: redundant conformance of 'SFTPDropTargetNSView' to protocol 'NSDraggingDestination'` on macOS 15+ because NSView already adopts the protocol.
- **Fix:** Declared as `final class SFTPDropTargetNSView: NSView` — NSDraggingDestination override methods still compile and function correctly.
- **Files modified:** MobaAlt/Views/SFTP/SFTPDropTargetView.swift
- **Commit:** 3b38f68 (fix inline, no separate commit needed)

## Verification Results

```
NSDraggingDestination:
  - registerForDraggedTypes([.fileURL]) at init
  - performDragOperation dispatches upload tasks via Task @MainActor
  - draggingEntered/Exited show/hide overlay with accentColor tint

sftpDefaultPosition in PreferencesView:
  - @AppStorage("sftpDefaultPosition") private var sftpDefaultPosition: SFTPPanelPosition = .left
  - Segmented Picker bound to $sftpDefaultPosition

Test suite: 73 tests passed, 0 failures
```

## Self-Check: PASSED

Files created/modified:
- FOUND: MobaAlt/Views/SFTP/SFTPTransferFooter.swift
- FOUND: MobaAlt/Views/SFTP/SFTPDropTargetView.swift
- FOUND: MobaAlt/Views/SFTP/SFTPPanelView.swift
- FOUND: MobaAlt/Views/SFTP/SFTPFileListView.swift
- FOUND: MobaAlt/Views/Preferences/PreferencesView.swift

Commits verified: 3b38f68, b97fa88
