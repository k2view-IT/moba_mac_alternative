---
phase: 02-ssh-terminal-sessions
plan: "01"
subsystem: terminal
tags: [swiftterm, ssh, spm, tdd, models]

# Dependency graph
requires:
  - phase: 01-app-foundation-and-session-management
    provides: ConnectionProtocol, SSHConfig, SessionDefinition models and xcodegen project setup
provides:
  - SwiftTerm 1.12.0 SPM dependency resolved and building
  - PortForwardingRule struct with ForwardingDirection enum (Codable, Hashable)
  - CommandSnippet struct (Codable, Hashable)
  - SSHConfig.portForwardingRules field with backward-compat decoding
  - 7 Wave 0 test scaffold files in RED state (failing stubs)
  - CommandSnippetTests in GREEN state
affects:
  - 02-02 (SSH terminal view uses SwiftTerm, SSHConfig models)
  - 02-03 (SSHArgumentBuilder uses PortForwardingRule, SSHConfig)
  - 02-04 (TabManager tests scaffold)
  - 02-05 (SessionLogWriter tests scaffold)
  - 02-06 (SSHKeyGenerator tests scaffold)

# Tech tracking
tech-stack:
  added: [SwiftTerm 1.12.0]
  patterns: [TDD RED-state test scaffolds committed before implementation, backward-compat decoding via decodeIfPresent]

key-files:
  created:
    - MobaAlt/Models/PortForwardingRule.swift
    - MobaAlt/Models/CommandSnippet.swift
    - MobaAltTests/SSHArgumentBuilderTests.swift
    - MobaAltTests/TabManagerTests.swift
    - MobaAltTests/SSHConnectionTests.swift
    - MobaAltTests/SessionLogWriterTests.swift
    - MobaAltTests/SSHKeyGeneratorTests.swift
    - MobaAltTests/CommandSnippetTests.swift
    - MobaAltTests/TerminalViewWrapperTests.swift
  modified:
    - project.yml
    - MobaAlt.xcodeproj/project.pbxproj
    - MobaAlt.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - MobaAlt/Models/ConnectionProtocol.swift

key-decisions:
  - "SwiftTerm requires Metal Toolchain component — downloaded via xcodebuild -downloadComponent MetalToolchain before build succeeded"
  - "SSHConfig backward-compat: custom init(from:) using decodeIfPresent for portForwardingRules so old session JSON without the field decodes without error"
  - "CommandSnippetTests implemented fully (GREEN) since CommandSnippet type exists; all other Wave 0 scaffolds use #expect(Bool(false), \"not implemented\") stubs"

patterns-established:
  - "Wave 0 test scaffolds: create all test files before any implementation tasks in the phase — RED state validates TDD structure"
  - "Backward-compat Codable: use decodeIfPresent with fallback default when adding new fields to persisted structs"

requirements-completed: [SSH-01, SSH-03, SSH-04, SSH-05, TERM-01, TERM-02, TERM-03, TERM-04, TERM-05]

# Metrics
duration: 5min
completed: 2026-03-22
---

# Phase 02 Plan 01: SwiftTerm SPM Dependency, Phase 2 Data Models, and Wave 0 Test Scaffolds Summary

**SwiftTerm 1.12.0 added as SPM dependency, PortForwardingRule and CommandSnippet models created, SSHConfig extended with portForwardingRules (backward-compat), and 7 TDD Wave 0 test scaffold files committed in RED state**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-22T10:28:20Z
- **Completed:** 2026-03-22T10:33:30Z
- **Tasks:** 2 completed
- **Files modified:** 13

## Accomplishments
- SwiftTerm 1.12.0 resolves and the project builds successfully with it as a dependency (required Metal Toolchain download)
- PortForwardingRule (with ForwardingDirection enum) and CommandSnippet models created with Codable/Hashable conformances
- SSHConfig extended with `portForwardingRules: [PortForwardingRule]` and a backward-compatible custom Codable init
- 7 Wave 0 test scaffold files committed in RED state — compile cleanly, fail with "not implemented" stubs
- CommandSnippetTests implemented fully and passing GREEN

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SwiftTerm SPM dependency and regenerate Xcode project** - `6346c42` (chore)
2. **Task 2: Create PortForwardingRule and CommandSnippet models, extend SSHConfig, write Wave 0 test scaffolds** - `d99daf7` (feat)

## Files Created/Modified
- `project.yml` - Added SwiftTerm package and MobaAlt target dependency
- `MobaAlt.xcodeproj/project.pbxproj` - Regenerated with xcodegen (includes SwiftTerm)
- `MobaAlt.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` - SwiftTerm 1.12.0 pinned
- `MobaAlt/Models/PortForwardingRule.swift` - ForwardingDirection enum + PortForwardingRule struct
- `MobaAlt/Models/CommandSnippet.swift` - CommandSnippet struct (Identifiable, Codable, Hashable)
- `MobaAlt/Models/ConnectionProtocol.swift` - Added portForwardingRules field + backward-compat init(from:)
- `MobaAltTests/SSHArgumentBuilderTests.swift` - Wave 0 scaffold (6 failing stubs)
- `MobaAltTests/TabManagerTests.swift` - Wave 0 scaffold (4 failing stubs)
- `MobaAltTests/SSHConnectionTests.swift` - Wave 0 scaffold (1 failing stub)
- `MobaAltTests/SessionLogWriterTests.swift` - Wave 0 scaffold (1 failing stub)
- `MobaAltTests/SSHKeyGeneratorTests.swift` - Wave 0 scaffold (1 failing stub)
- `MobaAltTests/CommandSnippetTests.swift` - Fully implemented, passing GREEN
- `MobaAltTests/TerminalViewWrapperTests.swift` - Wave 0 scaffold (1 failing stub)

## Decisions Made
- SwiftTerm requires the Metal Toolchain Xcode component which was not installed. Downloaded via `xcodebuild -downloadComponent MetalToolchain` (704MB) — this is a one-time machine setup requirement.
- SSHConfig needed a custom `init(from:)` using `decodeIfPresent` to maintain backward compatibility with existing sessions.json files that lack `portForwardingRules`. The plan specified adding the field but didn't address decoding backward-compat; added automatically as a correctness requirement (Rule 1 bug fix).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed SSHConfig backward-compatible decoding for portForwardingRules**
- **Found during:** Task 2 (test execution revealed SessionStore decoding errors)
- **Issue:** Adding `portForwardingRules` to SSHConfig without a custom `init(from:)` caused `keyNotFound` errors when decoding existing session JSON that lacks the field
- **Fix:** Added custom `init(from:)` using `decodeIfPresent` with fallback `[]` for `portForwardingRules`; also added explicit memberwise init for non-decoder construction
- **Files modified:** `MobaAlt/Models/ConnectionProtocol.swift`
- **Verification:** SessionStoreTests and MXTParserTests still pass; no decoding errors in test output
- **Committed in:** `d99daf7` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Essential correctness fix — without it existing user session data would fail to load after update.

## Issues Encountered
- Metal Toolchain was not installed on the machine; build initially failed with "cannot execute tool 'metal'". Resolved by downloading the component via `xcodebuild -downloadComponent MetalToolchain`. This is a one-time machine setup, not a code issue.

## User Setup Required
None - no external service configuration required. (Metal Toolchain was downloaded automatically during plan execution.)

## Next Phase Readiness
- SwiftTerm 1.12.0 is available for import in Phase 2 implementation tasks
- All 7 Wave 0 test scaffolds are in place — subsequent plans can implement GREEN against these tests
- PortForwardingRule and CommandSnippet types are available to all Phase 2 plans via @testable import MobaAlt
- No blockers for 02-02 through 02-06

---
*Phase: 02-ssh-terminal-sessions*
*Completed: 2026-03-22*

## Self-Check: PASSED
- FOUND: MobaAlt/Models/PortForwardingRule.swift
- FOUND: MobaAlt/Models/CommandSnippet.swift
- FOUND: MobaAltTests/CommandSnippetTests.swift (GREEN)
- FOUND: commit 6346c42 (Task 1)
- FOUND: commit d99daf7 (Task 2)
