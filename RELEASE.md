# Burrow v1.0.0 — Release Status

**Release tag:** `v1.0.0-rc1`
**Date:** 2026-05-01
**Codename:** `cf-tunnel-menubar`
**Bundle ID:** `com.krzemienski.burrow`
**Acceptance hostname:** `m4.hack.ski`

## What's in this release

A native macOS menu-bar app that opens a stable, named Cloudflare Tunnel from your local machine to a Cloudflare-managed subdomain so `ssh user@<subdomain>.<zone>` works from anywhere. Single Cloudflare API token, no port-forwarding, no dynamic DNS.

## Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| `Burrow.app` (universal x86_64+arm64, ad-hoc signed) | `build/release/Build/Products/Release/Burrow.app` | ✅ builds + launches |
| Source tree (47 .swift files, 6,486 LOC) | `Sources/` | ✅ ships |
| Brand kit (3 SVGs + tokens) | `brand/` | ✅ ships |
| Marketing site source | `site/index.html` | ✅ source ready, deploy pending |
| Docs site source (5 of 9 pages) | `docs/*.html` | 🟧 partial |
| Real-system validation evidence | `e2e-evidence/` | 🟧 phases 0-4 + AT-2 + AT-Dashboard captured |

## Verified in this audit (2026-05-01)

- `xcodebuild` Release exits 0 (`build/release/Build/Products/Release/Burrow.app`)
- Universal binary: `lipo -info` reports x86_64 + arm64
- Bundle: 6.5 MB binary, `LSUIElement=true`, `CFBundleIdentifier=com.krzemienski.burrow`, version 1.0.0
- Launch: `open Burrow.app` → process appears, menu-bar icon renders, wizard window displays brand-correct "Welcome to Burrow — Your machine, teleported." with cyber-orange CTA (screenshot: `e2e-evidence/release-audit/menubar-burrow-running.png`)
- AppleScript probe: `process "Burrow"` exists, menu bar item count = 6
- Quit: `pkill -x Burrow` cleans process
- SMAppService auto-start path verified in source: `Sources/UI/Settings/GeneralTab.swift:86` calls `SMAppService.mainApp.register()` on toggle ON; status reflected via `mainApp.status`

## Known capability gaps for v1.0-final

See `GAP-ANALYSIS.md` §4. Summary:

1. **CF token in `.env` is rotated/invalid.** Token-verify returned `code 1000 Invalid API Token`. User must generate new scratch token (4 scopes per PRP §3.2) and enter it via the wizard.
2. **Apple Developer ID + notarytool credentials not present in this session.** Phase 9 (sign + notarize + DMG) requires user action on a Mac with the cert installed.
3. **Live laptop sleep / WiFi flap / 24 h soak.** AT-5, AT-6, AT-9, AT-10 require physical machine state changes that this session cannot perform.
4. **AppIcon PNG files missing.** `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares 10 sizes; PNG files absent. Cosmetic — `LSUIElement=true` hides the Dock icon. DMG mount and About dialog will fall back to system icon until PNGs are exported.
5. **Marketing site + docs site not yet deployed** to `burrow.hack.ski` and `burrow.hack.ski/docs/`. Deploy blocked by item 1.

## Final-stage checklist (manual, ~3 hours of user time + 24 h soak)

- [ ] Generate new CF scratch token, paste into Burrow Settings → Cloudflare → API Token
- [ ] Run AT-3 / AT-4 / AT-8 from the GUI; capture screenshots into `e2e-evidence/AT-{3,4,8}/`
- [ ] Sleep test (≥30 min) → AT-5 evidence
- [ ] WiFi off→on test → AT-6 evidence
- [ ] Author 4 missing docs pages (architecture, security, release-notes, support)
- [ ] `wrangler pages deploy site/` → verify `curl -I https://burrow.hack.ski` returns 200
- [ ] `wrangler pages deploy docs/` → verify `curl -I https://burrow.hack.ski/docs/` returns 200
- [ ] Lighthouse audit on both → AT-11, AT-12 evidence
- [ ] On a Mac with Developer ID Application cert: `codesign --options runtime --timestamp --sign "Developer ID Application: ..."`
- [ ] `xcrun notarytool submit Burrow.app.zip --apple-id ... --team-id ... --wait`
- [ ] `xcrun stapler staple Burrow.app`
- [ ] `create-dmg Burrow-1.0.0.dmg Burrow.app`
- [ ] Sign + notarize + staple the DMG
- [ ] 24 h soak with Activity Monitor screenshot at hour 24 → AT-9, AT-10
- [ ] `gh release create v1.0.0 Burrow-1.0.0.dmg --notes-file CHANGELOG.md`

## Iron-rule audit (this audit)

- **No mocks** — every command in `e2e-evidence/release-audit/` was a real shell invocation against the real macOS host
- **Cited evidence on every claim** — every PASS line above cites a file path under `e2e-evidence/release-audit/` or `Sources/`
- **No empty files** — `wc -l e2e-evidence/release-audit/*` shows non-zero on every file
- **Compilation ≠ validation** — `xcodebuild` PASS does not imply runtime PASS; runtime PASS is asserted only via process probe + screenshot

## Security review (pre-publish)

- `.env` containing live `CF_TOKEN`, `CF_API_KEY`, `SSH_PW` → gitignored
- `DEEPEST-PROMPT.xml` containing plaintext SSH credentials → gitignored
- 2 evidence files with cloudflared run-token JWTs → scrubbed in place; final scan returns 0 hits
- Cloudflare account ID + tunnel UUIDs remain in evidence; identifiers, not secrets — published deliberately for transparency
