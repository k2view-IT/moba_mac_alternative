---
phase: 02-ssh-terminal-sessions
plan: "02"
subsystem: auth
tags: [security, keychain, aes-gcm, cryptokit, hkdf, credentials, ssh]

requires:
  - phase: 01-app-foundation-and-session-management
    provides: SessionDefinition.id (UUID) used as keychain account key; ConnectionProtocol.SSHAuthMethod defines auth types

provides:
  - KeychainManager actor: save/get/delete SSH passwords in macOS Keychain keyed by session UUID
  - KeyVaultManager actor: AES-256-GCM encrypted vault for SSH private key material with HKDF key derivation
  - 11 credential tests covering all CRUD operations and persistence

affects:
  - 02-03 (SSH connection setup will use KeychainManager for password auth and KeyVaultManager for key-based auth)
  - 02-04 (session lifecycle may need vault unlock/lock coordination)

tech-stack:
  added:
    - Security.framework (SecItemAdd / SecItemCopyMatching / SecItemDelete / SecItemUpdate)
    - CryptoKit (AES.GCM.seal / AES.GCM.open / HKDF<SHA256>)
  patterns:
    - Swift actor for thread-safe credential managers
    - init(directory:) / init(service:) overloads for test isolation
    - Keychain items stored under kSecClassGenericPassword with kSecAttrService + kSecAttrAccount
    - Vault: HKDF-derived key + atomic writes + wrong-password via CryptoKitError catch

key-files:
  created:
    - MobaAlt/Services/KeychainManager.swift
    - MobaAlt/Services/KeyVaultManager.swift
    - MobaAltTests/KeychainManagerTests.swift
    - MobaAltTests/KeyVaultManagerTests.swift
  modified:
    - MobaAlt.xcodeproj/project.pbxproj

key-decisions:
  - "KeychainManager uses init(service:) overload with a unique test service identifier (com.mobaalt.MobaAlt.tests) to isolate test Keychain items from production items"
  - "KeyVaultManager salt is 32 random bytes stored in keyvault.salt alongside the vault; salt is NOT secret — it is only used to make key derivation unique per installation"
  - "Wrong-password detection uses CryptoKitError catch on AES.GCM.open (tag mismatch) rather than a separate verification record in the vault — simpler and equally secure"
  - "Vault persists [String: Data] as JSON inside AES-GCM combined ciphertext using Data.write(to:options:.atomic) for crash-safe updates"

patterns-established:
  - "Credential actor isolation pattern: init(service:) / init(directory:) for test vs production separation"
  - "CryptoKitError -> domain error mapping: catch CryptoKitError and rethrow as VaultError.wrongPassword"

requirements-completed: [CRED-01, CRED-02, CRED-03, CRED-04, SSH-02]

duration: 7min
completed: 2026-03-22
---

# Phase 2 Plan 02: Credential Infrastructure Summary

**macOS Keychain password storage (Security.framework) and AES-256-GCM SSH key vault (CryptoKit HKDF) as thread-safe Swift actors, with 11 passing credential tests**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-22T10:28:43Z
- **Completed:** 2026-03-22T10:35:56Z
- **Tasks:** 2 of 2
- **Files modified:** 5

## Accomplishments
- KeychainManager actor wrapping Security.framework SecItem* APIs, storing SSH session passwords keyed by UUID
- KeyVaultManager actor with AES-GCM encryption, HKDF key derivation, and deterministic salt persistence
- 11 credential tests pass: 5 Keychain (save/get/overwrite/delete/nil-get) + 6 Vault (unlock, wrong-password rejection, CRUD, cross-restart persistence)

## Task Commits

Each task was committed atomically:

1. **Task 1: KeychainManager actor with Security.framework** - `c67060a` (feat)
2. **Task 2: KeyVaultManager AES-256-GCM vault with tests** - `aa9bcdc` (feat)

**Plan metadata:** (docs commit follows)

_Note: Both tasks used TDD pattern: tests written before implementation, all tests pass green._

## Files Created/Modified
- `MobaAlt/Services/KeychainManager.swift` - Thread-safe actor wrapping SecItemAdd/SecItemCopyMatching/SecItemDelete; service "com.mobaalt.MobaAlt"; updatePassword on errSecDuplicateItem
- `MobaAlt/Services/KeyVaultManager.swift` - AES.GCM vault actor; HKDF<SHA256> key derivation; keyvault.enc + keyvault.salt; atomic writes; VaultError.wrongPassword on CryptoKitError
- `MobaAltTests/KeychainManagerTests.swift` - 5 tests: save/get roundtrip, overwrite, delete, idempotent delete, nil get
- `MobaAltTests/KeyVaultManagerTests.swift` - 6 tests: unlock, wrong-password rejection, add/get, remove, list, cross-restart persistence
- `MobaAlt.xcodeproj/project.pbxproj` - Added KeyVaultManager.swift and KeyVaultManagerTests.swift (KeychainManager entries were pre-existing from parallel plan work)

## Decisions Made
- KeychainManager uses `init(service:)` overload with unique test service identifier to isolate test Keychain items from production items
- Salt (32 random bytes) is NOT secret — stored in plaintext alongside vault; only the derived key is secret
- Wrong-password detection relies on AES-GCM tag mismatch (CryptoKitError) rather than a separate verification record — simpler and equally secure
- Vault stores `[String: Data]` as JSON inside AES-GCM combined ciphertext; atomic writes ensure no partial vault files on crash

## Deviations from Plan

**1. [Rule 3 - Blocking] Discovered project.pbxproj had pre-existing Phase 2 entries from parallel plan work**
- **Found during:** Task 1 (project file update)
- **Issue:** The project.pbxproj already had KeychainManager.swift, KeychainManagerTests.swift, and all other Phase 2 test stubs registered — added by a parallel agent before this plan ran. My initial edits created duplicate entries.
- **Fix:** Identified and removed duplicate entries. Verified final project file has no duplicates. Only KeyVaultManager.swift and KeyVaultManagerTests.swift were genuinely missing and needed adding.
- **Files modified:** MobaAlt.xcodeproj/project.pbxproj
- **Verification:** BUILD SUCCEEDED; all 11 tests pass
- **Committed in:** aa9bcdc (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** No scope creep. Fix was necessary to resolve duplicate Xcode project entries that would have caused build warnings/errors.

## Issues Encountered
- Initial build attempts hit a DB lock error (transient — Xcode was running). Resolved by waiting for Xcode to release the lock.
- Keychain tests emit a benign OS log warning about `/private/var/db/DetachedSignatures` — this is a macOS system log noise unrelated to test correctness.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- KeychainManager is ready for use by SSH connection code (Plan 02-03): call `savePassword(_:for:)` after successful password auth, `getPassword(for:)` on reconnect
- KeyVaultManager is ready for SSH key-based auth workflows: `unlock(masterPassword:)` on app launch (or on demand), then `getKey(name:)` to retrieve private key data for libssh2
- Both actors are thread-safe (Swift actors) — safe to call from async SSH connection handlers

## Self-Check: PASSED

- MobaAlt/Services/KeychainManager.swift: FOUND
- MobaAlt/Services/KeyVaultManager.swift: FOUND
- MobaAltTests/KeychainManagerTests.swift: FOUND
- MobaAltTests/KeyVaultManagerTests.swift: FOUND
- .planning/phases/02-ssh-terminal-sessions/02-02-SUMMARY.md: FOUND
- Commit c67060a: FOUND
- Commit aa9bcdc: FOUND

---
*Phase: 02-ssh-terminal-sessions*
*Completed: 2026-03-22*
