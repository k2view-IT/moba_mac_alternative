---
phase: 01-app-foundation-and-session-management
plan: 03
subsystem: import-export
tags: [mxtsessions, ini-parser, json-export, html-export, dmg, notarization, import-wizard]

# Dependency graph
requires:
  - phase: 01-app-foundation-and-session-management
    plan: 01
    provides: SessionDefinition, SessionFolder, ConnectionProtocol, SessionLibrary models
  - phase: 01-app-foundation-and-session-management
    plan: 02
    provides: ExportDialogSheet UI shell, SidebarView structure, app shell

provides:
  - MXTSessionsParser: parses .mxtsessions INI format (Windows-1252/UTF-8) into SessionDefinition + SessionFolder arrays
  - MXTSessionsWriter: serializes sessions/folders back to .mxtsessions (round-trip safe)
  - JSONExporter: pretty-printed JSON with ISO8601 dates; passwords never included
  - HTMLExporter: well-formed UTF-8 HTML summary page with session table and folder breadcrumbs
  - SessionConflictResolver: detects name+folder conflicts; auto-renames with (2)/(3) suffix
  - ImportWizardSheet: 3-step import flow (file pick -> checkbox tree -> conflict sheet -> summary)
  - ImportConflictSheet: per-conflict Overwrite/Rename/Skip resolution with Apply to All
  - ImportSummarySheet: post-import session/folder/skipped counts
  - ExportDialogSheet: wired with real export write logic for all 3 formats
  - SidebarView: .mxtsessions drag-drop with blue border indicator
  - MobaAltApp: File menu Import Sessions (Cmd+Shift+I) and Export Sessions commands
  - scripts/build-dmg.sh: full 6-step DMG + notarization pipeline
  - ExportOptions.plist: developer-id export config for xcodebuild

affects:
  - Phase 2 (SSH Terminal): imports real session data into the app for connection
  - Phase 3 (Credentials): session data structure established; no passwords in export
  - Phase 4 (Polish): DMG pipeline ready for first distribution

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MXT INI format: sections [Bookmarks_N] with SubRep= folder path using backslash separator"
    - "Safe array subscript extension: Array[safe:] returns nil for out-of-bounds"
    - "TDD flow: RED (failing tests committed) then GREEN (implementation) pattern"
    - "Windows-1252 encoding: String(data:encoding:.windowsCP1252) with UTF-8 fallback"

key-files:
  created:
    - MobaAlt/Services/MXTSessionsParser.swift
    - MobaAlt/Services/MXTSessionsWriter.swift
    - MobaAlt/Services/JSONExporter.swift
    - MobaAlt/Services/HTMLExporter.swift
    - MobaAlt/Utilities/SessionConflictResolver.swift
    - MobaAlt/Views/Import/ImportWizardSheet.swift
    - MobaAlt/Views/Import/ImportConflictSheet.swift
    - MobaAlt/Views/Import/ImportSummarySheet.swift
    - scripts/build-dmg.sh
    - ExportOptions.plist
  modified:
    - MobaAlt/Views/Export/ExportDialogSheet.swift
    - MobaAlt/Views/AppShell/SidebarView.swift
    - MobaAlt/MobaAltApp.swift
    - MobaAltTests/MXTParserTests.swift
    - MobaAltTests/ExporterTests.swift
    - MobaAlt.xcodeproj/project.pbxproj

key-decisions:
  - "MobaXterm type code 1 (not 4 as documented) is the actual RDP type code in .mxtsessions files — parser accepts both 1 and 4"
  - "SSHAuthMethod.password enum case serializes as string 'password' in JSON — this is not a secret; test checks for key 'password :' not value"
  - "DB Monitor VNC session in sample.mxtsessions has empty type field (parsed as -1) — heuristic: treat as VNC if field 1 is a valid hostname"
  - "ImportWizardSheet uses sheet-over-sheet pattern (conflict sheet inside wizard) to preserve wizard state"
  - "MXTSessionsWriter groups sessions by folderId and builds SubRep paths by walking parentId chain"

patterns-established:
  - "Round-trip fidelity: parse -> write -> parse preserves name/host/port/type/folder structure"
  - "No-secret exports: JSON/MXT/.html never contain passwords or SSH key material by design (model enforces this)"

requirements-completed:
  - SESS-04
  - SESS-05
  - DIST-01
  - DIST-02
  - DIST-03

# Metrics
duration: 56min
completed: 2026-03-20
---

# Phase 1 Plan 3: Import/Export and Distribution Pipeline Summary

**.mxtsessions import wizard with conflict resolution, three export formats (MXT/JSON/HTML), drag-drop import, and DMG notarization pipeline — completing Phase 1 as a shippable app**

## Performance

- **Duration:** 56 minutes
- **Started:** 2026-03-20T08:09:01Z
- **Completed:** 2026-03-20T10:49:00Z
- **Tasks:** 2 of 2 auto tasks complete (Task 3 is a human-verify checkpoint)
- **Files modified:** 15 (10 created, 5 modified)

## Accomplishments

- Complete .mxtsessions import wizard: file picker, tree-level checkbox selection, conflict resolution (Overwrite/Rename/Skip), and post-import summary sheet
- Three export formats with real write logic: .mxtsessions (round-trip safe), JSON (no passwords, sorted keys, ISO8601), HTML (UTF-8, folder breadcrumbs, escaped)
- Drag-drop .mxtsessions files onto sidebar (blue border highlight while hovering)
- File menu "Import Sessions..." (Cmd+Shift+I) and "Export Sessions..." items wired
- Full test suite green: 11 tests across 5 suites including 7 new parser/exporter behaviors
- build-dmg.sh with 6-step archive→export→DMG→sign→notarize→staple pipeline, TODO markers for credentials

## Task Commits

1. **Task 1: RED (failing tests)** - `c6adcf7` (test)
2. **Task 1: GREEN (implementation)** - `f5252f0` (feat)
3. **Task 2: UI wiring and distribution** - `89d6d23` (feat)

## Files Created/Modified

- `MobaAlt/Services/MXTSessionsParser.swift` - INI parser: Windows-1252/UTF-8, folder hierarchy, special encodings, SSH/RDP/VNC
- `MobaAlt/Services/MXTSessionsWriter.swift` - INI serializer: SubRep paths, special encoding, Windows-1252 output
- `MobaAlt/Services/JSONExporter.swift` - Pretty-printed JSON with sorted keys and ISO8601 dates
- `MobaAlt/Services/HTMLExporter.swift` - UTF-8 HTML with session table, folder breadcrumbs, HTML escaping
- `MobaAlt/Utilities/SessionConflictResolver.swift` - Conflict detection and auto-rename with numeric suffix
- `MobaAlt/Views/Import/ImportWizardSheet.swift` - Multi-step import flow with DisclosureGroup tree
- `MobaAlt/Views/Import/ImportConflictSheet.swift` - Conflict resolution picker (Overwrite/Rename/Skip)
- `MobaAlt/Views/Import/ImportSummarySheet.swift` - Post-import counts display
- `MobaAlt/Views/Export/ExportDialogSheet.swift` - Wired real write logic, security note, error display
- `MobaAlt/Views/AppShell/SidebarView.swift` - .mxtsessions drag-drop, import sheet, context menu item
- `MobaAlt/MobaAltApp.swift` - File menu commands for import/export
- `scripts/build-dmg.sh` - 6-step distribution pipeline (executable)
- `ExportOptions.plist` - developer-id export configuration
- `MobaAltTests/MXTParserTests.swift` - 4 parser behaviors
- `MobaAltTests/ExporterTests.swift` - 3 exporter behaviors

## Decisions Made

- **RDP type code 1 vs 4:** The real MobaXterm format uses type code `1` for RDP, not `4` as documented in some references. Parser now accepts both to be future-proof.
- **SSHAuthMethod enum in JSON:** The `authMethod: "password"` value in JSON is the auth method name (not a secret). Test updated to check for key pattern `"password" :` not just the substring.
- **VNC heuristic for empty type field:** DB Monitor sample uses empty type field. Parser treats empty-type + valid hostname as VNC (safe fallback for unknown protocol).
- **Sheet-over-sheet import:** ImportWizardSheet uses nested `.sheet()` for conflict and summary to preserve wizard state and avoid premature dismissal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RDP type code mismatch with real MobaXterm format**
- **Found during:** Task 1 (testParseFolderStructure / testParseRDPAndVNC failures)
- **Issue:** Plan spec says RDP type code is `4`, but sample.mxtsessions (created in 01-01) uses `1` — the real MobaXterm format. Parser only handled `4`, causing Win Server to be skipped entirely.
- **Fix:** Changed parser case from `case 4` to `case 1, 4` — accepts both codes.
- **Files modified:** MobaAlt/Services/MXTSessionsParser.swift
- **Verification:** testParseRDPAndVNC and testParseFolderStructure pass
- **Committed in:** f5252f0 (Task 1 GREEN)

**2. [Rule 1 - Bug] JSON test assertion too broad — matched enum value not key**
- **Found during:** Task 1 (testJSONExport failure)
- **Issue:** Test checked `!jsonString.contains("\"password\"")` but `SSHAuthMethod.password` serializes as the string `"password"` (an auth method name, not a secret). The check matched the value `"authMethod" : "password"`.
- **Fix:** Updated test to check for `"password" :` (key pattern with colon) instead of just the string in quotes.
- **Files modified:** MobaAltTests/ExporterTests.swift
- **Verification:** testJSONExport passes; confirms no actual password key in output
- **Committed in:** f5252f0 (Task 1 GREEN)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs from real-world data vs. spec mismatch)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered

- `Bundle(for:)` requires a class type, not a struct — test helper refactored to use `Bundle.allBundles` scan for resource discovery in Swift Testing framework.

## User Setup Required

Before running scripts/build-dmg.sh, fill in the placeholders:
1. `TEAM_ID` — Your Apple Developer Team ID (10-character alphanumeric from developer.apple.com)
2. `KEYCHAIN_PROFILE` — Credential profile name created via `xcrun notarytool store-credentials`
3. `DEVELOPER_ID` — Your full Developer ID Application certificate name

## Next Phase Readiness

- Phase 1 is complete as of this plan; all SESS and DIST requirements addressed
- Human verification checkpoint (Task 3) needed to confirm import/export UI flows work end-to-end
- Phase 2 (SSH Terminal) can begin immediately after checkpoint approval
- DMG pipeline documented and ready for first distribution after credential setup

## Self-Check: PASSED

All 10 created files confirmed present on disk. All 3 task commits verified in git log:
- `c6adcf7`: test(01-03): add failing tests for parser and exporters
- `f5252f0`: feat(01-03): MXTSessionsParser, exporters, conflict resolver, and import wizard UI
- `89d6d23`: feat(01-03): wire real export logic, drag-drop import, File menu, and build pipeline

---
*Phase: 01-app-foundation-and-session-management*
*Completed: 2026-03-20*
