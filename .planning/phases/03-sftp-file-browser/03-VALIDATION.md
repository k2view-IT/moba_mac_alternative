---
phase: 3
slug: sftp-file-browser
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) |
| **Config file** | MobaAltTests/ (existing test target) |
| **Quick run command** | `xcodebuild test -project MobaAlt.xcodeproj -scheme MobaAlt -destination 'platform=macOS' -only-testing:MobaAltTests/SFTPBrowserServiceTests 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild test -project MobaAlt.xcodeproj -scheme MobaAlt -destination 'platform=macOS' 2>&1 \| tail -20` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command (SFTPBrowserServiceTests only)
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | SFTP-01 | unit | quick run | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | SFTP-02 | unit | quick run | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | SFTP-03, SFTP-04 | unit + manual | quick run | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | SFTP-05 | unit | quick run | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 3 | SFTP-01 | manual | — | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MobaAltTests/SFTPBrowserServiceTests.swift` — stubs for SFTP-01 through SFTP-05 using MockSFTPChannel
- [ ] `MobaAlt/Services/SFTPBrowserService.swift` — SFTPChannel protocol + stub implementation
- [ ] `MobaAltTests/SFTPFileTransferTests.swift` — stubs for upload/download progress tracking

*Existing XCTest infrastructure covers all other needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SFTP panel auto-opens alongside SSH terminal | SFTP-01 | Requires live SSH connection with ControlMaster socket | Connect to SSH session → verify SFTP panel appears on left within 2s |
| Drag file from Finder into SFTP panel uploads | SFTP-03 | NSDropDelegate with live filesystem | Drag a file from Desktop onto SFTP panel → verify it appears in remote listing |
| Drag file from SFTP panel to Finder downloads | SFTP-04 | NSFilePromiseProvider with live filesystem | Drag a remote file to Desktop → verify file downloaded |
| Double-click file opens locally | SFTP-04 | Requires live server + NSWorkspace.open | Double-click remote file → verify it downloads to /tmp and opens |
| ControlMaster socket reuse (no re-auth) | SFTP-01 | Requires running SSH session | Open SSH tab → SFTP connects without password prompt |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
