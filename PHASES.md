# Burrow — Phase Tracker

> Source of truth for execution status. One row per phase from PRP §4.
> Each phase advances only when its evidence artifact is captured under `e2e-evidence/phase-NN/` and is non-empty.

**Last updated:** 2026-04-30 — scaffold complete, ready for Phase 0.

---

## Status legend

- ⬜ not started
- 🟧 in progress
- ✅ complete (evidence captured)
- ❌ blocked (see notes)

---

| # | Phase | Status | Duration | Evidence file | Notes |
|---|-------|--------|----------|---------------|-------|
| 0 | Research & Lock-In | ⬜ | 30 min | `e2e-evidence/phase-00/token-verify.json` | Read all URLs in PRP §3.1, verify scratch CF token, confirm cloudflared installed |
| 1 | Project Scaffold | ⬜ | 60 min | `e2e-evidence/phase-01/menubar-screenshot.png` | Xcode project, MenuBarExtra renders, no Dock icon, KeychainAccess pinned to 4.2.2 |
| 2 | Cloudflare API Client | ⬜ | 3–4 hr | `e2e-evidence/phase-02/api-smoketest.log` | All 11 endpoints typed + smoke-tested against real CF account |
| 3 | Keychain & Preferences | ⬜ | 1 hr | `e2e-evidence/phase-03/persistence-relaunch.log` | Round-trip every prefs key + Keychain entry across app relaunch |
| 4 | cloudflared Lifecycle | ⬜ | 4–5 hr | `e2e-evidence/phase-04/ssh-via-tunnel.log` | Tunnel state machine wired; real SSH session captured through hostname |
| 5 | UI: MenuBar + Settings | ⬜ | 3–4 hr | `e2e-evidence/phase-05/settings-tabs-screenshots/` | All 5 tabs functional, screenshots per tab |
| 6 | First-Run Wizard | ⬜ | 3 hr | `e2e-evidence/phase-06/wizard-walkthrough.mov` | All 7 steps end-to-end, < 5 min completion |
| 7 | Reliability | ⬜ | 2 hr | `e2e-evidence/phase-07/wifi-flap-recovery.log` + `sleep-wake-recovery.log` | NWPathMonitor + PowerObserver + backoff + SMAppService |
| 8 | Acceptance Tests | ⬜ | 2–3 hr | `e2e-evidence/AT-1/` … `e2e-evidence/AT-10/` | 10 ATs from PRD §11.1, evidence + verdict per test |
| 9 | Notarize & Ship | ⬜ | 90 min | `e2e-evidence/phase-09/notarization-receipt.json` + DMG | Developer ID sign, notarize, staple, DMG, Gatekeeper verify |
| S1 | Marketing site scaffold | ⬜ | 60 min | `e2e-evidence/site/phase-S1/screenshot-*.png` | Single-page hand-written HTML + `brand/tokens.css` |
| S2 | Demo asset | ⬜ | 45 min | `e2e-evidence/site/phase-S2/demo.mp4` | Menubar transition idle → running, ≤ 800 KB |
| S3 | Lighthouse | ⬜ | 30 min | `e2e-evidence/site/phase-S3/lighthouse.json` | perf ≥ 90, a11y = 100, BP ≥ 95, SEO ≥ 95 |
| S4 | CF Pages deploy `burrow.hack.ski` | ⬜ | 45 min | `e2e-evidence/site/phase-S4/pages-deploy.json` | Custom domain wired, `curl -I` 200 |
| D1 | Docs scaffold + content | ⬜ | 3 hr | `e2e-evidence/docs/phase-D1/page-screenshots/` | 9 pages per PRD §19.2 |
| D2 | Static search index | ⬜ | 45 min | `e2e-evidence/docs/phase-D2/search-recall.log` | Lunr-style; 3 query recall sample |
| D3 | CF Pages deploy docs | ⬜ | 30 min | `e2e-evidence/docs/phase-D3/dns-record.json` | `burrow.hack.ski/docs` (recommended) |
| D4 | In-app deep link to docs | ⬜ | 15 min | `e2e-evidence/docs/phase-D4/click-to-browser.mov` | Settings → General → Open docs |

---

## Pre-Phase-0 readiness check

- [x] `PRD.md` finalized (v1.0.0, 2026-04-30)
- [x] `PRP.md` finalized (v1.0.0, 8.5/10 confidence)
- [x] `BRAND.md` locked (Burrow + cyber-orange)
- [x] Project directory tree scaffolded
- [x] `e2e-evidence/` skeleton created (phase-00 → phase-09, AT-1 → AT-10)
- [x] `.gitignore` written
- [x] `README.md` written
- [x] `CLAUDE.md` agent rules written
- [ ] Cloudflare scratch token created with 4 required scopes
- [ ] `cloudflared` confirmed installed and ≥ 2024.x.x
- [ ] Apple Developer credentials available for Phase 9 (`APPLE_ID`, `TEAM_ID`, app-specific password)

When all 11 boxes are checked, Phase 0 begins.

---

## Acceptance Tests (PRD §11.1)

| ID | Scenario | Phase gate | Status |
|----|----------|-----------|--------|
| AT-1 | Fresh install, complete wizard < 5 min | Phase 6 | ⬜ |
| AT-2 | SSH from mobile hotspot reaches local Mac | Phase 4 | ⬜ |
| AT-3 | Token verify with insufficient scope shows exact missing scope | Phase 6 | ⬜ |
| AT-4 | Subdomain change updates DNS, old record removed | Phase 5 | ⬜ |
| AT-5 | Sleep 30 min → wake → SSH works within 15s | Phase 7 | ⬜ |
| AT-6 | WiFi off → on → tunnel reconnects within 30s | Phase 7 | ⬜ |
| AT-7 | Quit app → no orphan `cloudflared` process | Phase 4 | ⬜ |
| AT-8 | Token revoked externally → app surfaces auth error within 60s | Phase 7 | ⬜ |
| AT-9 | 24h soak: tunnel up ≥ 99% with ≥ 3 sleep cycles | Phase 8 | ⬜ |
| AT-10 | Memory < 50 MB after 24h | Phase 8 | ⬜ |
| AT-11 | `burrow.hack.ski` returns 200 with brand-correct hero, Lighthouse perf ≥ 90 | Phase S3 | ⬜ |
| AT-12 | Docs page renders with left-rail nav, zero JS console errors | Phase D1 | ⬜ |
| AT-13 | App's Settings → General → Open documentation deep-links to live docs URL | Phase D4 | ⬜ |

---

## Iron Rules (recap from PRP §6)

1. No mocks. No test files. No XCTest target.
2. Every PASS verdict cites a specific file path under `e2e-evidence/`.
3. Empty files = invalid evidence.
4. Compilation ≠ validation.
5. Phase N is complete only when its artifact is captured and the smoke test passes against real services.
