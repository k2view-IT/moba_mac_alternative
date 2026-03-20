---
phase: 01-app-foundation-and-session-management
plan: "01"
subsystem: foundation
tags: [xcode-project, data-models, persistence, session-management, swift-actor]
dependency_graph:
  requires: []
  provides:
    - ConnectionProtocol (SSH/RDP/VNC discriminated union with type+config JSON shape)
    - SessionDefinition (full session entity with sortOrder, notes, folderId)
    - SessionFolder (hierarchy with parentId, sortOrder)
    - SessionLibrary (@Observable in-memory store with CRUD and search)
    - SessionStore (Swift actor for atomic JSON persistence with backup/restore)
    - AtomicFileWriter (thin wrapper for future encryption extension)
    - MobaAlt.entitlements (Hardened Runtime, no App Sandbox)
  affects:
    - All subsequent plans (01-02, 01-03, 02+) import these types directly
tech_stack:
  added:
    - Swift 6.2 / Swift 5.9 language features
    - SwiftUI (app shell)
    - Observation framework (@Observable macro)
    - Foundation (Process, FileManager, JSON encoding)
    - Swift Testing (test target, @Test macro)
    - xcodegen 2.45.3 (project generation)
  patterns:
    - Swift actor for thread-safe persistence
    - Discriminated union with custom Codable (type+config JSON shape)
    - onMutation hook for decoupled persistence wiring
    - Atomic file write with .backup fallback for crash safety
key_files:
  created:
    - MobaAlt.xcodeproj/project.pbxproj
    - MobaAlt/MobaAltApp.swift
    - MobaAlt/Views/ContentView.swift
    - MobaAlt/Info.plist
    - MobaAlt/Resources/MobaAlt.entitlements
    - MobaAlt/Models/ConnectionProtocol.swift
    - MobaAlt/Models/SessionDefinition.swift
    - MobaAlt/Models/SessionFolder.swift
    - MobaAlt/Models/SessionLibrary.swift
    - MobaAlt/Services/SessionStore.swift
    - MobaAlt/Utilities/AtomicFileWriter.swift
    - MobaAltTests/EntitlementTests.swift
    - MobaAltTests/SessionStoreTests.swift
    - MobaAltTests/SessionLibraryTests.swift
    - MobaAltTests/ExporterTests.swift
    - MobaAltTests/MXTParserTests.swift
    - MobaAltTests/Fixtures/sample.mxtsessions
    - project.yml
    - .gitignore
  modified: []
decisions:
  - "Used xcodegen (installed via Homebrew) instead of manual project.pbxproj creation — generates correct project structure from declarative YAML"
  - "SessionStore exposes init(directory:) overload for tests to use temp directories, avoiding Application Support pollution during test runs"
  - "ConnectionProtocol uses {type, config} JSON discriminator shape (not Swift's default associated-value encoding) for forward-compatibility with future protocol additions"
  - "SessionLibrary.onMutation closure defaults to no-op, keeping the model layer decoupled from persistence for easier testing"
  - "AtomicFileWriter is a thin free function (not a type) — sufficient for current use; can be evolved to a type with encryption in Phase 2"
metrics:
  duration_minutes: 7
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_created: 19
  files_modified: 0
---

# Phase 1 Plan 01: Xcode Project, Data Models, and Session Store Summary

**One-liner:** Native macOS 14 Xcode project with SSH/RDP/VNC discriminated union models, Swift actor JSON persistence with backup/restore, and @Observable session library.

## What Was Built

### Task 1: Xcode Project Scaffold

- Generated `MobaAlt.xcodeproj` via xcodegen from `project.yml` with macOS 14.0 deployment target, Swift 5.9, and Hardened Runtime enabled
- `MobaAlt.entitlements` — empty plist dict (no `com.apple.security.app-sandbox` key); Hardened Runtime enabled in build settings
- Minimal `MobaAltApp.swift` with `@main` entry point and session library state wiring
- Test target `MobaAltTests` linked to the app target with Swift Testing framework
- `EntitlementTests.swift` — `testProcessSpawn()` spawns `/bin/echo` via `Foundation.Process` and asserts exit code 0
- Wave 0 test stubs for `SessionStoreTests`, `SessionLibraryTests`, `ExporterTests`, `MXTParserTests`
- `sample.mxtsessions` fixture: 3 sessions (SSH root, RDP in Production, VNC in Production\DB), Windows CRLF, Windows-1252 encoding

### Task 2: Data Models, SessionLibrary, and SessionStore

**ConnectionProtocol.swift:**
- `enum ConnectionProtocol: Codable, Hashable` with cases `.ssh(SSHConfig)`, `.rdp(RDPConfig)`, `.vnc(VNCConfig)`
- Custom `CodingKey`-based encode/decode producing `{"type":"ssh","config":{...}}` shape
- Computed properties: `protocolName`, `hostname`, `port`

**SessionDefinition.swift:**
- `struct SessionDefinition: Identifiable, Codable, Hashable`
- Fields: `id (UUID)`, `name`, `folderId (UUID?)`, `protocolConfig`, `notes`, `sortOrder (Int)`, `createdAt`, `lastConnected`
- Passwords never stored; comment documents Keychain key pattern

**SessionFolder.swift:**
- `struct SessionFolder: Identifiable, Codable, Hashable`
- `parentId: UUID?` (nil = root), `sortOrder: Int`, `isExpanded: Bool = true`

**SessionLibrary.swift:**
- `@Observable final class SessionLibrary` — source of truth for UI
- CRUD methods for sessions and folders
- `sessions(inFolder:)` — sorted by sortOrder, `subfolders(of:)` — sorted by sortOrder
- `search(query:)` — case-insensitive name or hostname match; returns all when query is empty
- `deleteFolder(id:)` — recursively deletes child sessions and subfolders
- `onMutation: () async -> Void` hook (default no-op) for persistence wiring

**SessionStore.swift (actor):**
- Dual initializer: `init()` for production (Application Support) and `init(directory:)` for tests
- `save(sessions:folders:)` — backs up existing files (.backup extension) before atomic write
- `load()` — returns `([], [])` if files absent; falls back to backup on decode failure

**AtomicFileWriter.swift:**
- Free function `atomicWrite(_:to:)` wrapping `Data.write(to:options:.atomic)`

**Tests (fully implemented):**
- `testCreateSession` — full SSH field round-trip (all SSHConfig fields, notes, sortOrder, timestamp precision)
- `testFolderHierarchy` — parentId relationship + sortOrder preservation through save/load cycle
- `testSearch` — name match, hostname match, empty query returns all

## Verification Results

- All app Swift source files type-check without errors (verified via `xcrun swiftc -typecheck`)
- `MobaAlt.entitlements` plist contains empty dict (confirmed via `plistlib`)
- `sample.mxtsessions` has 3 sessions across 2 non-root folders (confirmed via parsing)
- `ConnectionProtocol` JSON shape uses `{type, config}` discriminator (confirmed via source analysis)
- No SwiftData imports anywhere in the codebase

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] xcodegen not installed**
- **Found during:** Task 1
- **Issue:** `xcodegen` command not found; `xcodebuild` requires full Xcode installation
- **Fix:** Installed xcodegen via Homebrew (`brew install xcodegen`); used it to generate the Xcode project from `project.yml`
- **Files modified:** None (no code change required)
- **Commit:** 7c3cd84

**2. [Rule 1 - Limitation] xcodebuild not functional (Xcode not installed)**
- **Found during:** Task 1 verification step
- **Issue:** Only Xcode Command Line Tools installed; `xcodebuild build` fails with "requires Xcode"
- **Fix:** Used `xcrun swiftc -typecheck` for Swift compilation validation. All source files type-check without errors. Swift Testing macro plugins require full Xcode to execute tests, but the test code is syntactically correct and will run when Xcode is installed.
- **Impact:** Build verification is via swiftc type-checking rather than `xcodebuild build`. Test execution deferred until Xcode is available.
- **Files modified:** `MobaAlt/Views/ContentView.swift` — removed `#Preview` macro (requires Xcode plugin infrastructure; not needed for functionality)
- **Commit:** 7c3cd84

## Self-Check

Files exist:
- [x] MobaAlt.xcodeproj/project.pbxproj — created
- [x] MobaAlt/MobaAltApp.swift — created
- [x] MobaAlt/Models/ConnectionProtocol.swift — created
- [x] MobaAlt/Models/SessionDefinition.swift — created
- [x] MobaAlt/Models/SessionFolder.swift — created
- [x] MobaAlt/Models/SessionLibrary.swift — created
- [x] MobaAlt/Services/SessionStore.swift — created
- [x] MobaAlt/Utilities/AtomicFileWriter.swift — created
- [x] MobaAlt/Resources/MobaAlt.entitlements — created (empty dict, no sandbox key)
- [x] MobaAltTests/SessionStoreTests.swift — created (full tests)
- [x] MobaAltTests/SessionLibraryTests.swift — created (full tests)
- [x] MobaAltTests/EntitlementTests.swift — created
- [x] MobaAltTests/Fixtures/sample.mxtsessions — created (3 sessions, 2 folders)

Commits exist:
- [x] 7c3cd84 — Task 1: project scaffold, entitlements, test stubs
- [x] b90feea — Task 2: data models, SessionLibrary, SessionStore, full tests
