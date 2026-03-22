---
phase: 03-sftp-file-browser
plan: 04
subsystem: ui
tags: [sftp, swiftui, appkit, nsfilepromissprovider, drag-drop, file-browser]

requires:
  - phase: 03-sftp-file-browser/03-01
    provides: SFTPItem model with name/path/size/modificationDate/isDirectory
  - phase: 03-sftp-file-browser/03-02
    provides: SFTPBrowserService with items/currentPath/isLoading/isConnected/showHidden
  - phase: 03-sftp-file-browser/03-03
    provides: SFTPPanelView type consumed by ContentView split layout; TabItem.sftpService

provides:
  - SFTPPanelView: top-level panel combining breadcrumb + file list + connection states
  - SFTPBreadcrumbBar: clickable path segment navigation bar
  - SFTPFileListView: sortable (name/size/date), multi-select, inline rename, context menu
  - SFTPFileRowView: NSViewRepresentable + SFTPDragSourceView with NSFilePromiseProvider drag-to-Finder
  - SFTPSortColumn enum: name, size, date

affects:
  - 03-05 (transfer footer slot stubbed in SFTPPanelView — 03-05 implements real footer)

tech-stack:
  added: []
  patterns:
    - "NSFilePromiseProvider + NSDraggingSource in NSView subclass for Finder drag-out (SwiftUI onDrag cannot deliver to Finder)"
    - "NSViewRepresentable overlay pattern: invisible SFTPDragSourceView (opacity 0.001) captures mouse drag events over SwiftUI row"
    - "Private BreadcrumbSegment struct with Int id for stable ForEach identity in SFTPBreadcrumbBar"
    - "@ViewBuilder extracted helper segmentView(_:) to resolve SwiftUI if/else type inference in ForEach"

key-files:
  created:
    - MobaAlt/Views/SFTP/SFTPPanelView.swift
    - MobaAlt/Views/SFTP/SFTPBreadcrumbBar.swift
    - MobaAlt/Views/SFTP/SFTPFileListView.swift
    - MobaAlt/Views/SFTP/SFTPFileRowView.swift
  modified:
    - MobaAlt/Views/AppShell/ContentView.swift
    - MobaAlt.xcodeproj/project.pbxproj

key-decisions:
  - "Used NSFilePromiseProvider for Finder drag-out — confirmed SwiftUI onDrag cannot satisfy Finder drop targets"
  - "NSViewRepresentable overlay at opacity 0.001 (not 0) to avoid SwiftUI optimization removing it from hit-testing"
  - "Private BreadcrumbSegment struct with sequential Int id avoids ForEach inference issues with tuples"
  - "@ViewBuilder extracted segmentView resolves if/else branching type inference in ForEach body"
  - "Xcode project file: SFTP files must be added to main app Sources phase (9C056477), not test phase (563A194F)"

patterns-established:
  - "NSFilePromiseProvider pattern: subclass NSView + NSDraggingSource + NSFilePromiseProviderDelegate; wrap in NSViewRepresentable"
  - "Context menu in SwiftUI List: .contextMenu { } on the row content inside List { } body"
  - "Inline rename: @State var renamingItemId: String? + TextField with .onSubmit + .onExitCommand"
  - "Multi-select: List(items, selection: $selectionSet) with Set<String> binding"

requirements-completed: [SFTP-02, SFTP-04, SFTP-05]

duration: 12min
completed: 2026-03-22
---

# Phase 3 Plan 04: SFTP Panel UI Views Summary

**Four SFTP panel views built: SFTPPanelView with breadcrumb navigation, sortable multi-select file list with NSFilePromiseProvider Finder drag-out, context menu, and inline rename**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-22T15:07:00Z
- **Completed:** 2026-03-22T15:12:44Z
- **Tasks:** 2
- **Files modified:** 6 (4 created, 2 modified)

## Accomplishments

- SFTPPanelView renders connection states (loading/connecting/connected) and hosts breadcrumb + file list
- SFTPBreadcrumbBar splits current path into clickable segments; `~` and absolute paths both handled
- SFTPFileListView: sortable by name/size/date (folders-first), multi-select via List binding, double-click nav, inline rename via Enter key
- SFTPFileListView context menu: New File, New Folder, Rename, Delete, Download (NSSavePanel), Copy Path
- SFTPFileRowView uses NSFilePromiseProvider so files can be dragged to Finder/Desktop — SwiftUI onDrag cannot accomplish this
- Cmd+Shift+. keyboard shortcut toggles showHidden on SFTPBrowserService
- All 73 tests pass; build succeeds with no errors

## Task Commits

1. **Task 1: SFTPPanelView and SFTPBreadcrumbBar** - `794a3fb` (feat)
2. **Task 2: SFTPFileListView and SFTPFileRowView** - `ba7bc28` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `MobaAlt/Views/SFTP/SFTPPanelView.swift` - Top-level panel; SFTPSortColumn enum; loading/connecting/file list states
- `MobaAlt/Views/SFTP/SFTPBreadcrumbBar.swift` - Clickable path segments; BreadcrumbSegment struct; segmentView @ViewBuilder helper
- `MobaAlt/Views/SFTP/SFTPFileListView.swift` - Sorted file list; column headers; multi-select; double-click; context menu; inline rename
- `MobaAlt/Views/SFTP/SFTPFileRowView.swift` - NSViewRepresentable + SFTPDragSourceView; NSFilePromiseProvider Finder drag-out
- `MobaAlt/Views/AppShell/ContentView.swift` - Removed private SFTPPanelView stub (replaced by real type)
- `MobaAlt.xcodeproj/project.pbxproj` - SFTP group + 4 files registered in main app Sources build phase

## Decisions Made

- NSFilePromiseProvider over SwiftUI onDrag: Finder requires NSFilePromiseProvider; onDrag only works for SwiftUI-to-SwiftUI drops
- NSViewRepresentable overlay at opacity 0.001 not 0: ensures NSView stays in hit-testing tree
- BreadcrumbSegment private struct: `ForEach` inference fails with tuple types; a named Identifiable struct resolves it
- Extracted `segmentView(_:) @ViewBuilder`: if/else returning different view types in ForEach body caused type inference failures; extracted helper resolves it

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] ForEach with Array(segments.enumerated()) caused type inference errors**
- **Found during:** Task 1 (SFTPBreadcrumbBar compilation)
- **Issue:** `ForEach(Array(segments.enumerated()), id: \.offset)` produced "cannot convert to Binding<C>" due to Swift overload resolution conflict in SwiftUI
- **Fix:** Replaced with private `BreadcrumbSegment: Identifiable` struct and extracted `segmentView(@ViewBuilder)` helper
- **Files modified:** MobaAlt/Views/SFTP/SFTPBreadcrumbBar.swift
- **Verification:** Build succeeded after fix
- **Committed in:** `794a3fb` (Task 1 commit)

**2. [Rule 3 - Blocking] SFTP files initially added to wrong Xcode build phase (test target)**
- **Found during:** Task 1 (project file registration)
- **Issue:** Script added files to Sources phase `563A194F` (MobaAltTests) instead of `9C056477` (MobaAlt main app)
- **Fix:** Removed entries from test phase and added to main app Sources phase
- **Files modified:** MobaAlt.xcodeproj/project.pbxproj
- **Verification:** SFTPPanelView now visible in main app scope; "cannot find SFTPPanelView in scope" error resolved
- **Committed in:** `794a3fb` (Task 1 commit)

**3. [Rule 1 - Bug] `.foregroundStyle(.accentColor)` unsupported — needs `Color.accentColor`**
- **Found during:** Task 1 (SFTPBreadcrumbBar compilation)
- **Issue:** `ShapeStyle` has no member `accentColor` in macOS 14 target
- **Fix:** Changed `.foregroundStyle(.accentColor)` to `.foregroundStyle(Color.accentColor)`
- **Files modified:** MobaAlt/Views/SFTP/SFTPBreadcrumbBar.swift
- **Verification:** Build succeeded
- **Committed in:** `794a3fb` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 blocking compilation, 1 API bug)
**Impact on plan:** All three were compile-time issues fixed inline. No scope creep.

## Issues Encountered

None beyond the auto-fixed compilation issues documented above.

## Next Phase Readiness

- SFTPPanelView is now fully functional; ContentView uses the real type (stub removed)
- Transfer footer stub (`Text("")`) at bottom of SFTPPanelView is ready for Plan 03-05 implementation
- File operations (createDirectory, rename, delete, download) are wired to context menu items
- NSFilePromiseProvider drag-out is ready for Finder drop targets

---
*Phase: 03-sftp-file-browser*
*Completed: 2026-03-22*
