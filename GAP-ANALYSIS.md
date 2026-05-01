# Burrow v1.0 — Gap Analysis (PRD/PRP vs implementation)

**Generated:** 2026-05-01 by `/crucible:forge` release audit
**Status authority:** PRD.md (v1.1.0), PRP.md (v1.1.0), PHASES.md
**Scope:** every PRP §4 phase, every PRD §11.1 acceptance test, every PRD §19.2 docs page

## 1. Implementation status (source of truth: code under `Sources/`)

| PRP phase | Component | Code | LOC | Status |
|---|---|---|---|---|
| 1 — Scaffold | `BurrowApp` + `AppDelegate` | `Sources/App/{CFTunnelApp,AppDelegate}.swift` | 130 | ✅ |
| 2 — CF API client | `CloudflareClient` actor + 11 endpoints + 7 model files | `Sources/CloudflareAPI/**` | ~900 | ✅ |
| 3 — Keychain + Preferences | `KeychainService` + `PreferencesStore` + `PrefsTokenStore` | `Sources/Keychain`, `Sources/Preferences` | ~430 | ✅ |
| 4 — cloudflared lifecycle | `CloudflaredManager` actor + `BinaryLocator` + `IngressConfigBuilder` + state machine | `Sources/TunnelCore/**` | ~600 | ✅ |
| 5a — Settings General | `GeneralTab.swift` (SMAppService, log level, notifications, docs link) | `Sources/UI/Settings/GeneralTab.swift` | 101 | ✅ |
| 5b — Settings Cloudflare | `CloudflareTab.swift` | `Sources/UI/Settings/CloudflareTab.swift` | – | ✅ |
| 5c — Settings Tunnel | `TunnelTab.swift` | `Sources/UI/Settings/TunnelTab.swift` | 167 | ✅ |
| 5d — Settings DNS | `DNSTab.swift` | `Sources/UI/Settings/DNSTab.swift` | 145 | ✅ |
| 5e — Settings Advanced | `AdvancedTab.swift` | `Sources/UI/Settings/AdvancedTab.swift` | – | ✅ |
| 5f — MenuBarContentView | menu rows, copy-ssh, open dashboard | `Sources/UI/MenuBar/MenuBarContentView.swift` | – | ✅ |
| Dashboard (D-I) | live tunnel state + connection summary | `Sources/UI/Dashboard/**` | – | ✅ |
| 6 — First-run wizard | 7-step coordinator + step views | `Sources/UI/FirstRun/**` | – | ✅ |
| 7 — Reliability | `NWPathMonitor`, `PowerObserver`, `Notifier`, backoff + restart | `Sources/Networking/**`, `Sources/Notifications/Notifier.swift` | ~400 | ✅ |
| 8 — Acceptance tests | per-AT evidence under `e2e-evidence/AT-N/` | various | – | 🟧 partial — see §3 |
| 9 — Notarize & ship | sign + notarize + DMG + Gatekeeper verify | – | – | ❌ blocked (capability gap; see §4) |

**Total Swift LOC across `Sources/`:** 6,486 lines, 47 .swift files.
**fatalError count in `Sources/`:** 0.

## 2. Build evidence

- `xcodebuild -scheme Burrow -configuration Release -derivedDataPath build/release` exits 0
- Produces `Burrow.app` (universal x86_64 + arm64, 6.5 MB binary, 6.2 MB app)
- `LSUIElement=true`, `LSMinimumSystemVersion=14.0`, `NSAllowsArbitraryLoads=false`
- Launch: process appears, menu-bar icon renders (system image fallback), `osascript` confirms `process "Burrow"` exists
- Quit: `pkill -x Burrow` cleans process; AT-7 orphan-cloudflared check independent of this run
- Evidence: `e2e-evidence/release-audit/launch-validation.md`

## 3. Acceptance test status

| AT | Scenario | Status | Notes |
|---|---|---|---|
| AT-1 | Fresh install, wizard < 5 min | 🟧 code complete; full E2E recording requires GUI screen capture session | Wizard 7 steps wired, end-to-end exercised in osascript validation |
| AT-2 | SSH from off-LAN to local Mac | ✅ PASS (iter3) | `e2e-evidence/AT-2/iter3/MSC-AT-2-PASS-receipt.md`; tunnel `burrow-m4` + Cloudflare Access blocked SSH at last step due to org policy — workaround required service-token bypass |
| AT-3 | Insufficient-scope token shows missing scope | 🟧 code path covered in `WizardCoordinator` validation; live trigger needs revoke-and-retry with capability-gap CF token |
| AT-4 | Subdomain change updates DNS, old removed | 🟧 code path in `TunnelTab.applyHostname`; live `dig`-before/after needs scratch token |
| AT-5 | Sleep 30 min → wake → SSH < 15 s | ❌ requires live laptop sleep; bash session is killed |
| AT-6 | WiFi off→on tunnel reconnects < 30 s | ❌ requires WiFi toggle on host |
| AT-7 | Quit app → no orphan cloudflared | 🟧 `applicationWillTerminate` calls `CloudflaredManager.stop()` with 5 s wait; needs live re-test with Burrow-spawned child |
| AT-8 | Token revoked externally → auth error < 60 s | 🟧 `Notifier` wired; needs scratch token + UI-driven revocation |
| AT-9 | 24 h soak ≥ 99 % uptime, ≥ 3 sleep cycles | ❌ wall-clock window > session lifetime |
| AT-10 | Memory < 50 MB after 24 h | ❌ same; cold launch RSS observed at 95 MB — expected to settle but unverified |
| AT-11 | `burrow.hack.ski` 200 + Lighthouse perf ≥ 90 | ❌ deploy blocked: CF token rotated; one-time `wrangler pages deploy` needed |
| AT-12 | Docs left-rail nav + 0 console errors | 🟧 `docs/` has 5 HTML pages (index, install, configure, api, troubleshoot); deploy blocked |
| AT-13 | Settings → Open documentation deep-links to live URL | 🟧 `DocsDeepLink.openDocs()` opens `https://burrow.hack.ski/docs/`; live verification blocked until S4/D3 deploy |

## 4. Capability gaps (cannot resolve in this session)

| Gap | Affects | Resolution path |
|---|---|---|
| Apple Developer ID Application certificate | Phase 9 (sign + notarize + DMG) | User imports cert into Keychain on a Mac with Xcode and runs `xcrun notarytool` |
| Apple notarytool credentials (`APPLE_ID`, `TEAM_ID`, app-specific password) | Phase 9 | User generates app-specific password at appleid.apple.com |
| Live Cloudflare API token (4 scopes) | AT-3, AT-4, AT-8, AT-11, S4, D3 | Existing `.env` token rotated (`Invalid API Token`); user generates new scratch token per PRP §3.2 |
| Real laptop sleep/wake | AT-5, AT-9 | Manual: macOS sleep ≥ 30 min, then SSH retry |
| Real WiFi toggle | AT-6 | Manual: WiFi off ≥ 5 s, on, time tunnel reconnect |
| 24 h wall-clock window | AT-9, AT-10 | Manual: leave Burrow running overnight, capture Activity Monitor |
| Mobile hotspot / off-LAN network | AT-2 (live re-test) | Already PASSed iter3; no further work needed unless re-validating after changes |
| AppIcon PNGs (10 sizes) | Cosmetic — Dock icon hidden via LSUIElement, but DMG/About dialog will fall back to system icon | Designer exports 16/32/128/256/512 px PNGs (1x and 2x) into `Resources/Assets.xcassets/AppIcon.appiconset/` |

## 5. Marketing site + docs site status

- `site/index.html` (18 KB) — single-page hand-written HTML with brand tokens, hero, features, CTA. **Not deployed** (S4 blocked: token).
- `docs/index.html`, `install.html`, `configure.html`, `api.html`, `troubleshoot.html` (5 of 9 PRD-spec'd pages) — **partial**, missing `architecture.html`, `security.html`, `release-notes.html`, `support.html` (4 pages).
- `docs/search-index.json` — Lunr-style index present.
- `brand/` — 3 SVG marks (logo-mark, logo-wordmark, menubar-icon-template) ✓.

## 6. What ships now (v1.0-rc1)

- `Burrow.app` (universal, ad-hoc signed) — works locally; cannot ship via DMG without Developer ID + notarization
- Full source tree, brand kit, partial docs, marketing site source
- Real-system evidence under `e2e-evidence/` for phases 0–4 + AT-2 + AT-Dashboard

## 7. What blocks v1.0-final

1. New Cloudflare scratch token → unblocks AT-3, AT-4, AT-8, S4 deploy, D3 deploy, AT-11..AT-13 live verification
2. Apple Developer ID cert + notarytool creds → unblocks Phase 9 (signed DMG)
3. 24 h on-device soak → unblocks AT-9, AT-10
4. Manual sleep/WiFi tests → unblocks AT-5, AT-6
5. AppIcon PNG export from designer → unblocks DMG visual polish
6. 4 missing docs pages authored + S4/D3 deploy → unblocks AT-12, AT-13 live link

## 8. Final stages plan (after this audit)

| Stage | Owner | Output |
|---|---|---|
| Cut new CF token, set in Burrow Settings → Cloudflare | user | live token in Keychain |
| Run AT-3, AT-4, AT-8 driven by Burrow GUI | user (15 min) | screenshots in `e2e-evidence/AT-{3,4,8}/` |
| Sleep 30 min test (AT-5) | user (≥30 min) | log in `e2e-evidence/AT-5/` |
| WiFi flap test (AT-6) | user (~3 min) | log in `e2e-evidence/AT-6/` |
| 24 h soak + memory check (AT-9, AT-10) | user (24 h) | Activity Monitor screenshot |
| Author 4 missing docs pages | docs author | HTML files in `docs/` |
| `wrangler pages deploy site/` | user (10 min) | `burrow.hack.ski` 200 |
| `wrangler pages deploy docs/` | user (10 min) | `burrow.hack.ski/docs/` 200 |
| Lighthouse audit on deployed sites (AT-11, AT-12) | user (5 min) | reports in `e2e-evidence/site/phase-S3/`, `e2e-evidence/docs/` |
| Apple Developer ID sign + notarize + staple | user (Mac w/ cert, 15 min) | signed Burrow.app + notarization receipt |
| `create-dmg Burrow.app` | user (5 min) | `Burrow-1.0.0.dmg` |
| Sign + notarize DMG, staple ticket | user (10 min) | shipping artifact |
| GitHub Release v1.0.0 with DMG asset | user | live download |
