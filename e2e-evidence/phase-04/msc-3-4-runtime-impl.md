# MSC-3 / MSC-4 Runtime Implementation Evidence
Run ID: 20260430T231540Z

## Files Modified / Created

| File | Pre LOC | Post LOC | fatalError pre | fatalError post |
|------|---------|---------|----------------|-----------------|
| Sources/Keychain/KeychainService.swift | 52 | 158 | 0 | 0 |
| Sources/TunnelCore/BinaryLocator.swift | 33 | 101 | 0 | 0 |
| Sources/TunnelCore/CloudflaredManager.swift | 72 | 197 | 1 | 0 |
| Sources/Preferences/PreferencesStore.swift | 62 | 128 | 0 | 0 |
| Sources/UI/Helpers/DocsDeepLink.swift | NEW | 10 | — | 0 |

Total fatalError/TODO stub bodies eliminated: **1** (CloudflaredManager.start)

---

## What Was Implemented

### MSC-3 — KeychainService (Security framework)
- `KeychainError.osstatus(OSStatus)` enum with `LocalizedError` conformance.
- `setAPIToken(_:)` — `kSecClassGenericPassword`, service `com.krzemienski.burrow`,
  account `api.token`, accessible `kSecAttrAccessibleAfterFirstUnlock`.
- `getAPIToken()` — returns `nil` on `-25300 errSecItemNotFound`, throws on other codes.
- `deleteAPIToken()` — silently succeeds on `errSecItemNotFound`.
- `setRunToken(_:tunnelID:)` — account `tunnel.run.<tunnelID>`,
  accessible `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- `getRunToken(tunnelID:)` / `deleteRunToken(tunnelID:)` — same nil/throw semantics.
- Private `upsert`: `SecItemUpdate` first; `SecItemAdd` on `-25300`; no duplicate-add path.
- Private `fetchData`: `SecItemCopyMatching` with `kSecReturnData` + `kSecMatchLimitOne`.
- Private `removeItem`: `SecItemDelete`; ignores `errSecItemNotFound`.
- `kSecAttrSynchronizable = kCFBooleanFalse` on every add — no iCloud sync.
- Token values never logged (only account key names at `.info` level via `Log.keychain`).

### MSC-4a — BinaryLocator
- `locate(customPath:)` — 4-probe chain:
  1. `PreferencesStore.customCloudflaredPath` if non-empty and `isExecutableFile`.
  2. `/opt/homebrew/bin/cloudflared`
  3. `/usr/local/bin/cloudflared`
  4. `/usr/bin/which cloudflared` subprocess fallback.
- `version(at:)` — spawns `cloudflared --version`, `waitUntilExit()` (version probe is
  fast; blocking acceptable per skill), regex `version (\d+\.\d+\.\d+)`.
- `whichCloudflared()` — private helper, checks `terminationStatus == 0`.

### MSC-4b — CloudflaredManager
- `start(runToken:)`:
  - Locates binary via `BinaryLocator.locate`; transitions to `.failed` + throws
    `CloudflaredManagerError.binaryNotFound` if nil.
  - Builds `Process` with `["tunnel", "run", "--token", runToken]`.
  - Attaches `Pipe` for stdout (drained silently) and stderr (streamed).
  - `readabilityHandler` on stderr: scrubs `--token \S+` via regex before any log call;
    routes ERR/error lines to `Log.tunnel.error`, WRN/warn to `.warning`, rest to `.info`;
    fires `markRunning()` on `"Registered tunnel connection"`.
  - `terminationHandler` dispatches to actor via `Task { await self?.handleExit(code:) }`.
  - `userInitiatedStop` flag prevents false `.failed` transitions on SIGTERM.
  - State: `.idle` → `.starting` (in `start`) → `.running` (in `markRunning`).
- `stop()`:
  - Sets `userInitiatedStop = true`.
  - `proc.terminate()` (SIGTERM).
  - Polls `proc.isRunning` every 100 ms up to 5 s using `ContinuousClock`.
  - Escalates to `kill(pid, SIGKILL)` if still alive.
  - Transitions to `.stopped`, clears `process`.
- `restart(runToken:)` — `stop()` + 1 s sleep + `start(runToken:)`.
- `handleExit(code:)` — tears down `readabilityHandler` on both pipes; sets `.stopped`
  for exit 0, `.failed(reason:)` for non-zero, no-ops if `userInitiatedStop`.
- `CloudflaredManagerError.binaryNotFound` enum with `LocalizedError`.

### MSC-D4-code — NSWorkspace deep-link
- `Sources/UI/Helpers/DocsDeepLink.swift` — `DocsDeepLink.openDocs()` opens
  `https://burrow.hack.ski/docs` via `NSWorkspace.shared.open(_:)`.

### MSC-PreferencesStore — UserDefaults bridge
- Suite: `UserDefaults(suiteName: "com.krzemienski.burrow")`, fallback `.standard`.
- Key prefix: `"burrow."` on all 12 stored properties.
- `init()` hydrates every property from `defaults` before first use.
- Every `didSet` writes back to `defaults` immediately — `@Observable` contract intact.
- `object(forKey:) != nil` guard used for `Bool`/`Int` properties to distinguish
  "never set" from explicit `false`/`0`.

---

## swiftc -typecheck Output

```
Command:
  swiftc -typecheck -target arm64-apple-macos14.0 \
    Sources/Keychain/KeychainService.swift \
    Sources/TunnelCore/TunnelState.swift \
    Sources/TunnelCore/BinaryLocator.swift \
    Sources/TunnelCore/CloudflaredManager.swift \
    Sources/Preferences/PreferencesStore.swift \
    Sources/Logging/Log.swift \
    Sources/CloudflareAPI/CloudflareError.swift \
    Sources/CloudflareAPI/Models/APIEnvelope.swift \
    Sources/CloudflareAPI/Models/Account.swift \
    Sources/CloudflareAPI/Models/Zone.swift \
    Sources/CloudflareAPI/Models/Tunnel.swift \
    Sources/CloudflareAPI/Models/DNSRecord.swift \
    Sources/CloudflareAPI/Models/TokenVerify.swift \
    Sources/UI/Helpers/DocsDeepLink.swift

Exit code: 0
Errors: 0
Warnings: 0
```

Note: PRP §0 states deployment target macOS 13.0 but `Burrow.xcodeproj/project.pbxproj`
has `MACOSX_DEPLOYMENT_TARGET = 14.0` (required for `@Observable` macro). Typecheck
uses the actual project target.

---

## Iron-Rule Compliance

- Real `Security` framework calls (`SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`,
  `SecItemDelete`) — no mock keychain wrapper.
- Real `Foundation.Process` + `Pipe` — no subprocess stub.
- Real `NSWorkspace.shared.open` — no mock URL opener.
- Token values never appear in any log call at any level.
- `fatalError` count: 0 in all modified files (was 1 in CloudflaredManager.start).
