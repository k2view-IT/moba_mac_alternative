---
phase: 1
slug: app-foundation-and-session-management
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro, macOS 14+) + XCTest fallback |
| **Config file** | None — Wave 0 creates Xcode project with test target |
| **Quick run command** | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme MobaAlt -destination 'platform=macOS'`
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green + DMG tested on clean account
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| Create/persist session | 01 | 1 | SESS-01 | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/SessionStoreTests/testCreateSession` | ❌ W0 | ⬜ pending |
| Folder hierarchy | 01 | 1 | SESS-02 | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/SessionStoreTests/testFolderHierarchy` | ❌ W0 | ⬜ pending |
| Search/filter sessions | 01 | 1 | SESS-03 | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/SessionLibraryTests/testSearch` | ❌ W0 | ⬜ pending |
| Import .mxtsessions | 02 | 2 | SESS-04 | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/MXTParserTests` | ❌ W0 | ⬜ pending |
| Export 3 formats | 02 | 2 | SESS-05 | unit | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/ExporterTests` | ❌ W0 | ⬜ pending |
| Hardened Runtime + process spawn | 03 | 3 | DIST-03 | smoke | `xcodebuild test -scheme MobaAlt -only-testing:MobaAltTests/EntitlementTests/testProcessSpawn` | ❌ W0 | ⬜ pending |
| DMG signed + Gatekeeper | 03 | 3 | DIST-01 | manual | Build + install on clean account | N/A | ⬜ pending |
| macOS 14 minimum target | 03 | 3 | DIST-02 | manual | Verify Xcode deployment target = macOS 14.0 | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MobaAlt.xcodeproj` — Xcode project with app target (`MobaAlt`) and test target (`MobaAltTests`)
- [ ] `MobaAltTests/SessionStoreTests.swift` — stubs for SESS-01, SESS-02 (CRUD + folder persistence)
- [ ] `MobaAltTests/SessionLibraryTests.swift` — stubs for SESS-03 (search/filter)
- [ ] `MobaAltTests/MXTParserTests.swift` — stubs for SESS-04 (.mxtsessions parsing)
- [ ] `MobaAltTests/ExporterTests.swift` — stubs for SESS-05 (JSON, HTML, .mxtsessions export)
- [ ] `MobaAltTests/EntitlementTests.swift` — smoke test: spawn Process successfully (DIST-03)
- [ ] `MobaAltTests/Fixtures/sample.mxtsessions` — sample MobaXterm export file for parsing tests
- [ ] Swift Testing framework available via Xcode 15+ (macOS 14+ target satisfies this)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DMG installs cleanly, no Gatekeeper warning | DIST-01 | Requires Developer ID cert + notarization + clean Mac | Build DMG, copy to clean account, double-click, verify opens without quarantine warning |
| macOS 14+ minimum enforced | DIST-02 | Deployment target is a build setting | Open Xcode → Project settings → Deployment target = 14.0; attempt build targeting macOS 13 (should fail) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
