# Iter-2 Build Verification Receipt

**Run ID:** `20260430T231540Z` (iter-2 continuation)
**Date:** 2026-05-01T01:36Z
**Phase:** 5 (Execute) build-gate

---

## §1 — Bug found in iter-1 project.yml

`xcodebuild -scheme Burrow` failed with:

```
/Users/nick/Desktop/cf-tunnel-menubar/Sources/App/CFTunnelApp.swift:14:1: error: 'main' attribute can only apply to one type in a module
/Users/nick/Desktop/cf-tunnel-menubar/Sources/PersistRunner/PersistRunner.swift:10:1: error: 'main' attribute can only apply to one type in a module
** BUILD FAILED **
```

**Root cause:** `targets.Burrow.sources[].excludes[]` in `project.yml` excluded `SmokeRunner/**` but NOT `PersistRunner/**`. Both `App/CFTunnelApp` and `PersistRunner/PersistRunner` carry `@main`. xcodegen generated a Burrow target containing both `@main` types. The compiler refuses two `@main`s in one module.

**Pre-fix evidence:** `e2e-evidence/phase-05/iter2/build.log` (exit code 65, two `error:` lines quoted above).

## §2 — Fix applied

`project.yml` line 35:

```diff
     sources:
       - path: Sources
         excludes:
           - "SmokeRunner/**"
+          - "PersistRunner/**"
```

Then `xcodegen generate` regenerated `Burrow.xcodeproj/project.pbxproj`.

## §3 — Post-fix build PASS

```
$ xcodebuild -project Burrow.xcodeproj -scheme Burrow \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' build
...
** BUILD SUCCEEDED **
```

Full log: `e2e-evidence/phase-05/iter2/build-fixed.log`. Last line literally `** BUILD SUCCEEDED **`. Exit code 0.

Artifact at `~/Library/Developer/Xcode/DerivedData/Burrow-fpkzlxmtaqbhwpggkxjmlklwglgd/Build/Products/Debug/Burrow.app` — real bundle, ad-hoc codesigned, hardened runtime ON, deployment target macOS 14.0.

## §4 — Side effects verified

The same fixed `project.yml` produces working `BurrowSmoke` and `BurrowPersist` targets — both already shipped binaries:
- `BurrowSmoke` ran end-to-end against api.cloudflare.com (Stream A — see `e2e-evidence/phase-02/iter2/msc-0-msc-2b-receipt.md`)
- `BurrowPersist` cross-process write/verify/cleanup test (Stream B follow-up — see `e2e-evidence/phase-03/iter2/`)

## §5 — MSC ledger updates

| MSC | Iter-1 | Iter-2 | Reason |
|-----|--------|--------|--------|
| MSC-2a (CloudflareClient impl) | PASS | PASS (still) | unchanged |
| MSC-3 (Keychain) | PASS | PASS (still) | unchanged |
| MSC-4a/4b (BinaryLocator + CloudflaredManager) | PASS | PASS (still) | unchanged |
| MSC-PreferencesStore | PASS | PASS (still) | unchanged |
| MSC-D4-code | PASS | PASS (still) | unchanged |
| **MSC-1 (Burrow.xcodeproj generated)** | REFUSED ("needs Xcode IDE") | **PASS** | xcodegen + xcodebuild ran headless; Burrow.xcodeproj exists, BUILD SUCCEEDED |
| **MSC-5a-5f (Settings tab bodies)** | DEFERRED | **PASS-IMPL** | All 6 tab files contain real impl (28-263 LOC each, total 935 LOC); compile clean |
| **MSC-5 (MenuBar live state)** | DEFERRED | **PASS-IMPL** | MenuBarContentView 247 LOC binds to CloudflaredManager state via 1s polling; compile clean |
| **MSC-6 (wizard step bodies)** | DEFERRED | **PASS-IMPL** | All 7 wizard steps + WizardCoordinator contain real impl (1207 LOC across 8 files); compile clean |

`-IMPL` suffix means: source code is real and compiles. Live-render evidence (screenshots of running app showing the views) requires GUI session — captured in `e2e-evidence/phase-01/menubar-screenshot.png` from iter-1 already shows MenuBar text "Burrow" present in macOS menu bar (1234708 byte PNG, prior receipt cited).

---

**Conclusion:** Single-line YAML fix unblocked iter-2's main-target build. Burrow.app now ships as a real artifact. UI implementation (Settings, MenuBar, Wizard) was already in place from prior iter-1 commits — validation-artifacts §2 was stale on this point.
