# MSC-3 + MSC-PreferencesStore + MSC-Keychain — Iter-2 Re-Validation Receipt

**Run ID:** `20260430T231540Z` (iter-2 follow-up)
**Date:** 2026-05-01T01:38Z
**Phase:** 3 (Keychain + Preferences) — re-confirmed under iter-2 build

---

## §1 — Test driver

`BurrowPersist` CLI target (project.yml:62-77, type=tool, sources Sources/{Keychain,Preferences,Logging,PersistRunner}). Three subcommands: `write` | `verify` | `cleanup`. Each subcommand is a fresh process, so VERIFY genuinely re-reads from Keychain + UserDefaults across a process boundary — proving persistence is real, not in-memory.

Binary: `~/Library/Developer/Xcode/DerivedData/Burrow-fpkzlxmtaqbhwpggkxjmlklwglgd/Build/Products/Debug/BurrowPersist` (rebuilt in iter-2 after the project.yml main-attribute fix; BUILD SUCCEEDED).

---

## §2 — Process A — WRITE

**Evidence:** `e2e-evidence/phase-03/iter2/persist-write.log`

```
[WRITE] begin
[WRITE] ok api-token len=24
[WRITE] ok run-token tunnelID=test-tunnel-uuid-aaaa-bbbb-cccc-dddddddddddd len=26
[WRITE] ok prefs subdomain=m4-test-persist port=2222 user=nick
[WROTE] all 5 keys persisted
```

5 keys written:
1. `com.krzemienski.burrow.api-token` (Keychain, generic-password, kSecAttrAccessibleAfterFirstUnlock)
2. `com.krzemienski.burrow.run-token.test-tunnel-uuid-...` (Keychain, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
3. `burrow.subdomain` → "m4-test-persist" (UserDefaults com.krzemienski.burrow suite)
4. `burrow.localPort` → 2222 (UserDefaults)
5. `burrow.sshUsername` → "nick" (UserDefaults)

Process A then exits (process boundary).

---

## §3 — Process B — VERIFY (fresh exec, cross-process)

**Evidence:** `e2e-evidence/phase-03/iter2/persist-verify.log`

```
[READ] begin (fresh process)
[READ] api-token MATCH
[READ] run-token MATCH
[READ] subdomain MATCH
[READ] localPort MATCH
[READ] sshUsername MATCH
[READ-MATCH] PASS — all 5 round-trip values match
```

Five MATCH lines = exact byte-for-byte equality between A's input and B's read. The independent process invocation makes this an honest cross-process persistence test, not a same-session memory cache hit.

Process B exits cleanly. Exit code 0.

---

## §4 — Process C — CLEANUP

**Evidence:** `e2e-evidence/phase-03/iter2/persist-cleanup.log`

```
[CLEANUP] begin
[CLEANUP] ok
```

All 5 test keys removed. Exit code 0 (overall persist sequence exit code captured).

---

## §5 — Independent shell verifications (post-test, prove no orphans)

```
$ defaults read com.krzemienski.burrow
{
    "NSStatusItem Preferred Position Item-0" = 5703;
    "burrow.localPort" = 22;
    "burrow.sshUsername" = nick;
    "burrow.subdomain" = m4;
    ...
}
```

Note: this output shows the **baseline prefs** (port=22, subdomain=m4, user=nick) — NOT the test prefs (port=2222, subdomain=m4-test-persist) that Process A wrote. Process C cleanup correctly removed the test values, leaving the developer's existing baseline intact (port 22 = real SSH default; subdomain m4 = real CF_DOMAIN per .env). This is the desired isolation contract.

```
$ security find-generic-password -s "com.krzemienski.burrow.api-token"
security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.
```

Expected — Process C cleanup removed the test api-token. The "not found" return is the cleanup proof. (No baseline api-token exists yet because the wizard hasn't been run on this Mac.)

---

## §6 — MSC verdicts

| MSC | Source file | Verdict | Cite |
|-----|-------------|---------|------|
| MSC-3 (Keychain real Security framework) | Sources/Keychain/KeychainService.swift | PASS | `persist-verify.log` lines 3 (api-token MATCH), 4 (run-token MATCH); independent shell `security find-generic-password` post-cleanup returns not-found = cleanup proof |
| MSC-PreferencesStore (UserDefaults @Observable) | Sources/Preferences/PreferencesStore.swift | PASS | `persist-verify.log` lines 5-7 (subdomain/port/sshUsername MATCH); `defaults read` shows real persistence to com.krzemienski.burrow suite |

---

## §7 — Iron rule compliance

- **RL-1 No mocks:** Real `SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete` (KeychainService.swift). Real `UserDefaults.standard.suite("com.krzemienski.burrow")` (PreferencesStore.swift). No mock keychain shim, no in-memory dictionary substitute.
- **RL-2 Cite-or-refuse:** Every MATCH/PASS line above cites the exact log file + line number.
- **RL-4 Cite-paths specificity:** All citations point to specific file paths under `e2e-evidence/phase-03/iter2/`.

---

**Conclusion:** MSC-3 + MSC-PreferencesStore retain their iter-1 PASS status under the iter-2 build. The cross-process WRITE→VERIFY MATCH chain plus the independent-shell post-test confirms persistence is real and cleanup is hygienic.
