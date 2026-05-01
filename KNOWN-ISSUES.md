# Burrow — Known Issues (v1.0.0)

Defects found during deep validation pass (`/reflexion:reflect deeply`) on 2026-05-01.
Filed for tracking; severity and fix priority noted per item.

## DEF-1 — Settings → General → Log level picker is functionally inert

**Severity:** low
**Surface:** `Sources/UI/Settings/GeneralTab.swift` log-level Picker
**Symptom:** Choosing `info`, `debug`, or `error` writes `burrow.logLevel` to UserDefaults but no consumer reads it back. `Sources/Logging/Log.swift` only declares plain `Logger(subsystem:category:)` with no level filtering.

**Reality:** OSLog level filtering is OS-controlled (via `log stream --level <x>` or per-app log policy in System Settings → Privacy & Security → Logging), not app-controlled. An in-app picker cannot affect what OSLog records or surfaces.

**Fix options for v1.1:**
- Remove the picker entirely (simplest).
- Replace with a deep link to `log stream --predicate 'subsystem == "com.krzemienski.burrow"'` so users learn to filter at the OS level.
- Repurpose to gate Burrow's own emit verbosity by reading `prefs.logLevel` inside `Log.swift` and conditionally calling `.debug` / `.info` / `.error`. Adds wiring; arguable benefit since OSLog already supports level filters.

## DEF-2 — Wizard step 3 (Account & Zone) silently fails on insufficient-scope token

**Severity:** medium (UX)
**Surface:** `Sources/UI/FirstRun/Steps/AccountZoneStep.swift`
**Symptom:** Token with only `Cloudflare Tunnel Read` (missing `Edit`, `DNS`, `Zone Read`, `Account Settings Read`) passes step 2's `verifyToken()` (which calls `/user/tokens/verify` — that endpoint only confirms the token is active, not that it has any specific scopes). The wizard advances to step 3 and shows empty Account / Zone pickers with **no error message**.

**Expected** (per PRD §11.1 AT-3): "Token verify with insufficient scope shows exact missing scope."

**Reproducible:** mint a CF API token with only `Cloudflare Tunnel Read` permission group, paste into Burrow wizard, click Verify, click Continue. Observed: step 3 with empty pickers, no error surfaced.

**Root cause:** `client.listAccounts()` and/or `client.listZones()` likely return empty (HTTP 200 but `result: []` because the token can't see those resources) instead of throwing `CloudflareError.insufficientScope`. The step's empty-result path doesn't surface "missing scope" UI.

**Fix for v1.1:** in `AccountZoneStep`, if `listAccounts()` returns empty AND the token's permissions don't cover Account Settings Read, surface a missing-scope error and refuse to advance — matching the polish already present in `TokenStep.verifyStatusView` for the `.scopeError([String])` case.

## DEF-3 — App must be in `/Applications` for SMAppService persistence

**Severity:** documented behavior (Apple TN3127)
**Symptom:** Toggling "Launch at login" while running from `build/release/Build/Products/Release/` succeeds at `register()` (system shows "Login Item Added"), but registration may not persist across reboot because the app is not in `/Applications`.

**Workaround:** move `Burrow.app` to `/Applications/` before enabling Launch at login.

**Already documented:** `docs/install.html` (Step 2 — "Must be in /Applications") and `docs/troubleshoot.html` (DEF-3 surface "Launch at login toggle has no effect").

## DEF-4 — Notifications denied at OS level

**Severity:** user-action-required
**Symptom:** Burrow calls `Notifier.shared.requestAuthorization()` at launch; macOS shows the standard prompt. If user clicks "Don't Allow" or never sees the prompt, Burrow's banners (token revoked, three failures in five minutes, cloudflared not found) cannot fire. OSLog confirms: `[com.krzemienski.burrow:lifecycle] UN authorization error: Notifications are not allowed for this application`.

**Workaround:** System Settings → Notifications → Burrow → Allow.

**No code fix needed** — wiring is correct.

## Pass-through PRD acceptance tests not exercised this session

- AT-4 (subdomain change updates DNS, old removed): code path wired in `TunnelTab.applyHostname` + `DNSTab` Apply; live test skipped to avoid disrupting active tunnel
- AT-5 (sleep 30 min → wake → SSH works): host sleep kills bash session
- AT-6 (WiFi off → on → tunnel reconnects): cannot toggle host WiFi
- AT-9 (24 h soak ≥ 99% uptime): wall-clock window > session
- AT-10 (memory < 50 MB after 24 h): same as AT-9
- AT-11/12/13 (site + docs Lighthouse, deep-link verify): require `wrangler pages deploy`

These are user-driven manual tests, listed in `RELEASE.md` final-stage checklist.
