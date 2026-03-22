---
phase: 02-ssh-terminal-sessions
plan: 04
subsystem: ui
tags: [swiftui, swiftterm, nsviewrepresentable, keychain, aes-gcm, macos]

# Dependency graph
requires:
  - phase: 02-03
    provides: TabManager, SSHConnection, SSHKeyGenerator, SessionLogWriter
  - phase: 02-02
    provides: KeyVaultManager, KeychainManager
provides:
  - TerminalTabBar — custom scrollable SwiftUI tab bar (ScrollView+HStack, not NSTabView)
  - TerminalTabView — NSViewRepresentable wrapping SSHConnection.terminalView
  - ContentView wired to TabManager — detail area shows tabs or placeholder
  - KeyVaultUnlockView — master password entry sheet
  - KeyVaultView — list/add/delete SSH keys in vault with generate button
  - CredentialPickerView — inline auth method picker for SessionEditorSheet
  - EnvironmentKeys — custom EnvironmentValues keys for actor-based services
  - Double-click to open session tabs from sidebar
affects:
  - 02-05
  - 02-06

# Tech tracking
tech-stack:
  added: []
  patterns:
    - NSViewRepresentable wrapping SwiftTerm LocalProcessTerminalView
    - EnvironmentKey pattern for actor types (not @Observable)
    - Custom ScrollView+HStack tab bar instead of NSTabView/SwiftUI.TabView

key-files:
  created:
    - MobaAlt/Views/Terminal/TerminalTabBar.swift
    - MobaAlt/Views/Terminal/TerminalTabView.swift
    - MobaAlt/Views/Credentials/KeyVaultUnlockView.swift
    - MobaAlt/Views/Credentials/KeyVaultView.swift
    - MobaAlt/Views/Credentials/CredentialPickerView.swift
    - MobaAlt/Utilities/EnvironmentKeys.swift
  modified:
    - MobaAlt/Views/AppShell/ContentView.swift
    - MobaAlt/Views/Sidebar/SessionRowView.swift
    - MobaAlt/MobaAltApp.swift
    - MobaAltTests/TerminalViewWrapperTests.swift

key-decisions:
  - "EnvironmentKey (not @Environment(Type.self)) required for actor-based services — actors don't conform to Observable so SwiftUI's @Observable-based environment injection doesn't work"
  - "KeyVaultView tracks isUnlocked as @State bool — actors can't be observed by SwiftUI directly, so we poll on appear instead of binding"
  - "TerminalTabView calls connection.start() in makeNSView if terminalView is nil — ensures exactly one start call per NSViewRepresentable lifecycle"

patterns-established:
  - "Pattern: EnvironmentValues custom key for actors — use EnvironmentKey + extension EnvironmentValues for any non-@Observable service passed through SwiftUI environment"
  - "Pattern: NSViewRepresentable for SwiftTerm — makeNSView starts the connection, updateNSView is a no-op (terminal manages its own rendering)"
  - "Pattern: Tab switching uses .id(activeTab.id) on TerminalTabView to force NSViewRepresentable recreation on tab change"

requirements-completed: [TERM-01, TERM-02, CRED-01, CRED-02, CRED-03, CRED-04, SSH-01]

# Metrics
duration: 10min
completed: 2026-03-22
---

# Phase 02 Plan 04: Terminal UI and Credential Views Summary

**Custom scrollable terminal tab bar + NSViewRepresentable SwiftTerm wrapper + three credential views (unlock/manage/pick) wired to KeyVaultManager and KeychainManager actors via EnvironmentKey**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-22T10:53:55Z
- **Completed:** 2026-03-22T10:58:58Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- TerminalTabBar: custom ScrollView+HStack tab bar with active indicator, truncated names, and xmark close buttons
- TerminalTabView: NSViewRepresentable starting SSHConnection exactly once in makeNSView; updateNSView is a no-op
- ContentView: detail area shows TabManager-backed terminal area (tab bar + view) or placeholder when no tabs; toolbar button opens KeyVaultView
- SessionRowView: double-click (.onTapGesture count:2) calls tabManager.openTab(for:) — re-added from Phase 1 removal
- Credential views: KeyVaultUnlockView (master password sheet), KeyVaultView (key list with generate flow), CredentialPickerView (password/key/agent inline picker)
- MobaAltApp: KeyVaultManager and KeychainManager injected via EnvironmentKey into WindowGroup
- TerminalViewWrapperTests: RED stub replaced with GREEN test verifying SSHConnection initial state

## Task Commits

Both tasks were part of the deviation fix in 02-05 (committed before 02-04 was formally executed):

1. **Task 1: Terminal tab UI — TerminalTabBar, TerminalTabView, ContentView wiring, double-click** - `135e77e` (feat)
2. **Task 2: Credential UI — KeyVaultUnlockView, KeyVaultView, CredentialPickerView** - `135e77e` (feat)

Note: All Task 1 and Task 2 files were committed atomically in `135e77e` (feat(02-05)) as a Rule 3 deviation fix — the 02-05 executor noticed 02-04 files were missing and created them before continuing.

## Files Created/Modified
- `MobaAlt/Views/Terminal/TerminalTabBar.swift` — custom ScrollView+HStack tab bar with active state indicators
- `MobaAlt/Views/Terminal/TerminalTabView.swift` — NSViewRepresentable wrapping LocalProcessTerminalView
- `MobaAlt/Views/Credentials/KeyVaultUnlockView.swift` — master password entry sheet with error handling
- `MobaAlt/Views/Credentials/KeyVaultView.swift` — SSH key list/add/delete with KeyGenSheet sub-sheet
- `MobaAlt/Views/Credentials/CredentialPickerView.swift` — inline password/privateKey/agent picker
- `MobaAlt/Utilities/EnvironmentKeys.swift` — EnvironmentKey + EnvironmentValues extensions for KeyVaultManager and KeychainManager
- `MobaAlt/Views/AppShell/ContentView.swift` — TabManager wired, detail area uses TerminalTabBar+TerminalTabView, KeyVaultView toolbar button
- `MobaAlt/Views/Sidebar/SessionRowView.swift` — double-click gesture calls tabManager.openTab(for:)
- `MobaAlt/MobaAltApp.swift` — KeyVaultManager and KeychainManager provided as environment values
- `MobaAltTests/TerminalViewWrapperTests.swift` — verifies SSHConnection initializes with .connecting state and nil terminalView

## Decisions Made
- **EnvironmentKey for actors:** KeyVaultManager and KeychainManager are Swift actors, not @Observable. SwiftUI's `@Environment(Type.self)` requires Observable conformance. Solution: `EnvironmentKey` protocol + `EnvironmentValues` extension — same result, works with any reference type.
- **isUnlocked @State tracking:** Since actors can't be observed by SwiftUI, KeyVaultView and CredentialPickerView track vault lock state as a local `@State var isUnlocked: Bool`, updated in `onAppear` via async call.
- **TerminalTabView start() in makeNSView:** connection.start() called in makeNSView if terminalView is nil, ensuring exactly one start per view creation. Tab switch uses `.id(activeTab.id)` to force NSViewRepresentable recreation.

## Deviations from Plan

### Note on Execution Order

All files for this plan were created by the 02-05 plan executor as a Rule 3 (blocking) deviation — it detected that 02-04 terminal/credential views were missing and created them before implementing 02-05's port forwarding views. When 02-04 was formally executed, all files were already committed and tests passing.

**1. [Rule 3 - Blocking] EnvironmentKey pattern for actor-based services**
- **Found during:** Task 2 (credential views)
- **Issue:** `@Environment(KeyVaultManager.self)` requires `@Observable` conformance. KeyVaultManager and KeychainManager are actors which don't conform to Observable
- **Fix:** Created `EnvironmentKeys.swift` with `EnvironmentKey` extensions for both managers; updated MobaAltApp to use `.environment(\.keyVaultManager, ...)` key-path injection
- **Files modified:** MobaAlt/Utilities/EnvironmentKeys.swift, MobaAlt/MobaAltApp.swift, all three credential views
- **Verification:** BUILD SUCCEEDED, all 45 tests pass
- **Committed in:** 135e77e

---

**Total deviations:** 1 auto-fixed (1 blocking — wrong environment injection API for actor types)
**Impact on plan:** Required fix — actors can't use @Observable-based environment injection. EnvironmentKey is the idiomatic SwiftUI alternative.

## Issues Encountered
- SwiftUI `@Environment(Type.self)` only works with `@Observable` types — actors require `EnvironmentKey` + `EnvironmentValues` extension pattern

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Terminal UI and credential views are fully functional
- SessionRowView double-click opens terminal tabs
- Credential picker can be embedded in SessionEditorSheet SSH tab
- KeyVaultView accessible from ContentView toolbar
- Ready for 02-05 (port forwarding) and 02-06 (polish/logging)

---
*Phase: 02-ssh-terminal-sessions*
*Completed: 2026-03-22*
