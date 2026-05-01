# Burrow

> Your machine, teleported.

A native macOS menu bar app that opens a stable Cloudflare Tunnel from your local machine to a subdomain on a Cloudflare-managed zone — so `ssh user@m4.hack.ski` (or any `<subdomain>.<zone>` you choose) works from anywhere, regardless of NAT, CGNAT, or DHCP churn.

v1.0 ships **three artifacts** together:

1. The macOS app — `Burrow.app` (Developer ID signed, notarized DMG).
2. The marketing site — `burrow.hack.ski` (static, Cloudflare Pages).
3. The documentation site — `burrow.hack.ski/docs` (static, Cloudflare Pages).

**Status:** scaffold complete · pre-Phase 0
**Codename:** `cf-tunnel-menubar`
**Product name:** `Burrow`
**Bundle ID:** `com.krzemienski.burrow`
**Acceptance hostname:** `m4.hack.ski`
**Target:** macOS 13+ Universal · Developer ID signed · notarized

---

## What it does

1. Accepts a single Cloudflare API token (Keychain-stored).
2. Creates a **named** Cloudflare Tunnel via CF API v4.
3. Provisions a stable CNAME `<subdomain>.<zone>` → `<tunnel_uuid>.cfargotunnel.com`.
4. Manages `cloudflared tunnel run` as a child process with ingress `ssh://localhost:22`.
5. Auto-recovers across network changes and sleep/wake.
6. Lets you copy `ssh user@<subdomain>.<zone>` from a one-click menu.

## What it is not

- Not a tunnel for HTTP / RDP / VNC / arbitrary TCP (v1.1+).
- Not multi-tunnel (v1.1+).
- Not bundled `cloudflared` — detect-or-guide flow.
- Not sandboxed in v1.0 — Developer ID + Hardened Runtime only.
- Not a test framework. Validation is real-system only. See `e2e-evidence/`.

## Repo layout

```
cf-tunnel-menubar/
├── README.md                         this file
├── BRAND.md                          Burrow brand lock — type, color, voice
├── PHASES.md                         Phase 0 → 9 tracker (PRP §4)
├── CLAUDE.md                         project guard rules for autonomous agents
├── PRD.md                            Product Requirements Document v1.0
├── PRP.md                            Product Requirement Prompt v1.0
├── .gitignore
├── Sources/                          Swift sources (PRP §3.7 layout)
│   ├── App/                          @main, AppDelegate
│   ├── TunnelCore/                   CloudflaredManager actor + state machine
│   ├── CloudflareAPI/                CF API v4 client + 11 endpoints + models
│   ├── Keychain/                     KeychainService
│   ├── Preferences/                  PreferencesStore (UserDefaults)
│   ├── Networking/                   NWPathMonitor + sleep/wake
│   ├── Logging/                      OSLog categories
│   └── UI/
│       ├── MenuBar/                  MenuBarExtra content
│       ├── Settings/                 5 tabs: General, Cloudflare, Tunnel, DNS, Advanced
│       └── FirstRun/                 7-step wizard
├── Resources/
│   └── Assets.xcassets/              AppIcon, AccentColor, MenuBarIcon
├── brand/                            logo SVGs, mockups exported from brand kit
├── e2e-evidence/                     real-system validation artifacts (no mocks)
│   ├── phase-00/ ... phase-09/
│   └── AT-1/ ... AT-10/
└── .agent/                           agent state, research, plans (gitignored)
    ├── state/
    ├── research/
    └── plans/
```

## Build prerequisites

- macOS 13 Ventura or later
- Xcode 15+
- `cloudflared` ≥ 2024.x.x (installed via `brew install cloudflared`)
- A Cloudflare account with at least one zone you control
- A Cloudflare API token with the four required scopes (see `BRAND.md` § 2 or PRP § 3.2)

## Quick start (after Phase 1 scaffold lands in Xcode)

```bash
# Pre-flight
which cloudflared || brew install cloudflared
cloudflared --version

# Verify your scratch Cloudflare token (replace $CF_TOKEN)
curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify | jq .

# Open the project once it exists
open Burrow.xcodeproj
```

## Validation

This project follows the **Iron Rules** in `PRP.md` § 6:

- No mocks, no test files, no fixtures. Real Cloudflare API only.
- No XCTest target.
- Every PASS verdict cites a specific file under `e2e-evidence/`.
- Empty files (0 bytes) are invalid evidence.
- Compilation is necessary but not sufficient.

See `PHASES.md` for the per-phase evidence checklist.

## Security

**Never paste a real Cloudflare API token into any file in this repo, any chat, any screenshot, any PR description.** Use a scratch token for development; rotate after every demo. The wizard → Keychain path is the only sanctioned credential surface. See PRD §20 + PRP §14.

If a token is exposed: dashboard → Roll/Delete → Re-enter via Burrow Settings → Cloudflare. Document the incident under `e2e-evidence/incidents/` with no token values quoted.

## License

TBD — pending Phase 9.

---

**Source-of-truth docs:** `PRD.md` (what + why) → `PRP.md` (exactly how) → `BRAND.md` (visual identity) → `PHASES.md` (execution tracker).
