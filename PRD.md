# Product Requirements Document
## Burrow — Cloudflare Tunnel SSH Menu Bar (macOS)

**Document Version:** 1.1.0
**Status:** Draft → Ready for Implementation (branding + scope locked)
**Date:** 2026-04-30
**Author:** Nick Krzemienski
**Target Release:** v1.0
**Product name:** `Burrow`
**Codename:** `cf-tunnel-menubar`
**Bundle ID:** `com.krzemienski.burrow`
**Acceptance hostname:** `m4.hack.ski`
**Brand authority:** `BRAND.md` (Hybrid Black Bean + Cyber Orange `#FF6A1A`)

---

## 1. Executive Summary

A native macOS menu bar application that exposes the user's local SSH server (`localhost:22`) to the public internet via a stable, named Cloudflare Tunnel, with automatic DNS provisioning on a Cloudflare-managed zone. The user provides a single Cloudflare API token; the app handles tunnel creation, credential storage, `cloudflared` daemon lifecycle, DNS CNAME management, and reconnection on network/sleep events.

**Primary outcome:** From a Mac on any network (home, office, mobile hotspot, hotel WiFi), the user runs `ssh user@m4.hack.ski` (the v1.0 acceptance hostname; any user-chosen `<subdomain>.<zone>` works the same way) and reaches their local machine — without port forwarding, dynamic DNS, or third-party tunnel registries.

---

## 2. Problem Statement

### 2.1 Current Pain
- Home/office NAT and CGNAT block inbound SSH.
- Dynamic IPs invalidate static DNS records.
- Existing tools (Bore, ngrok, localtunnel) generate ephemeral hostnames per session, breaking SSH config and `known_hosts`.
- Manually running `cloudflared` requires CLI fluency, YAML config authoring, and OS service plist setup.
- Credentials (API token, tunnel run token) end up in shell history, dotfiles, or plaintext config.

### 2.2 Solution
A single-binary menu bar app that:
1. Owns the Cloudflare API token in Keychain.
2. Creates a **named** tunnel once (stable `<uuid>.cfargotunnel.com` hostname).
3. Provisions a stable CNAME (`m4.domain.com → <uuid>.cfargotunnel.com`).
4. Runs `cloudflared` as a managed child process.
5. Auto-reconnects across network changes and sleep/wake.

---

## 3. Architecture Decision: Cloudflare-Only Stack

### 3.1 Chosen Architecture
| Layer | Technology | Rationale |
|-------|------------|-----------|
| Tunnel transport | Cloudflare Tunnel (`cloudflared`) | Stable hostname, no inbound port required, free tier sufficient |
| DNS | Cloudflare API v4 (Zones + DNS Records) | Same provider as tunnel, atomic CNAME provisioning |
| Auth | Single Cloudflare API token | One credential, scoped permissions, revocable |
| Daemon mgmt | Native `Process` API | Direct control over lifecycle, no LaunchAgent plist authoring |
| Storage | Keychain (secrets) + UserDefaults (prefs) | Native, sandbox-compatible |
| UI | SwiftUI `MenuBarExtra` + `Settings` scene | macOS 13+ native, minimal custom AppKit |

### 3.2 Explicitly Rejected
- **Bore / ngrok / localtunnel** — ephemeral hostnames, no DNS integration, third-party trust.
- **Bundled cloudflared (always)** — bloats binary, lags upstream releases. Use detect-or-install flow instead.
- **OAuth / Cloudflare Access login flow** — adds setup friction; API token covers all v1.0 needs.
- **Multiple tunnel providers in v1.0** — Cloudflare-only ships faster; multi-provider is v2+.

---

## 4. Goals & Non-Goals

### 4.1 Goals (v1.0)
- G1: Sub-5-minute first-run setup for non-CLI user with existing Cloudflare account.
- G2: SSH from external network reaches local Mac via configured subdomain.
- G3: Tunnel uptime ≥ 99% over 24h observation, including ≥ 3 sleep/wake cycles and ≥ 2 network changes.
- G4: Zero credential exposure in logs, exports, UI, or filesystem outside Keychain.
- G5: < 50 MB resident memory, near-zero idle CPU.
- G6: Tunnel established < 10 seconds after app launch (warm path: existing tunnel + DNS).

### 4.2 Non-Goals (v1.0)
- HTTP / RDP / VNC / arbitrary TCP ingress (v1.1+).
- Multiple simultaneous tunnels per app instance (v1.1+).
- Cloudflare Access policy configuration UI (v1.2+).
- Team / Zero Trust org switcher (v2+).
- Windows / Linux ports (out of scope).
- Bundled `cloudflared` updater (use Homebrew or guided install).
- Built-in SSH client (delegate to user's `ssh` + `~/.ssh/config`).

---

## 5. Personas

### P1: Solo Developer "Maya"
Has Cloudflare account for personal domain. Wants `ssh maya@m4.maya.dev` to work from anywhere. Comfortable pasting an API token; not comfortable writing YAML.

### P2: Indie Founder "Devon"
Operates from coffee shops on mobile hotspot. Needs reliable inbound to home Mac for occasional admin. Values "set once, forget" reliability over feature breadth.

### P3: Power User "Kai"
Already runs `cloudflared` manually. Wants menu bar visibility, copy-SSH-command convenience, and graceful sleep/wake — but expects to override `cloudflared` binary path and ingress YAML.

---

## 6. User Stories

| ID | Story | Priority |
|----|-------|----------|
| US-1 | As Maya, I paste my Cloudflare API token once and the app verifies its scopes. | P0 |
| US-2 | As Maya, I pick my zone and subdomain from a dropdown — I never type a UUID. | P0 |
| US-3 | As Devon, the menu bar shows green when tunnel is up, gray when down, spinner when reconnecting. | P0 |
| US-4 | As Devon, I click "Copy SSH command" and paste `ssh devon@m4.devon.io` into Terminal. | P0 |
| US-5 | As Devon, I close my laptop, reopen it, and the tunnel is back within 10s without me touching anything. | P0 |
| US-6 | As Kai, I override the `cloudflared` binary path in Advanced settings. | P1 |
| US-7 | As Kai, I view live `cloudflared` stdout/stderr in an Advanced log pane. | P1 |
| US-8 | As Maya, when my token is invalid the app says exactly which scope is missing. | P1 |
| US-9 | As anyone, I quit the app and my tunnel terminates cleanly with no orphan process. | P0 |
| US-10 | As anyone, I toggle "Launch at Login" once and the app starts on boot. | P1 |

---

## 7. Functional Requirements

### 7.1 Authentication & Onboarding
- FR-1.1 First-run wizard launches when no API token in Keychain.
- FR-1.2 Wizard step "API Token": SecureField + deep link to Cloudflare token-create page with required scopes pre-encoded in URL where supported.
- FR-1.3 On token paste, call `GET /client/v4/user/tokens/verify`; surface scope list and validity.
- FR-1.4 Required scopes (validated post-verify):
  - `Account → Cloudflare Tunnel → Edit`
  - `Zone → DNS → Edit`
  - `Zone → Zone → Read`
  - `Account → Account Settings → Read`
- FR-1.5 Wizard refuses to proceed if any required scope missing; lists exact missing scopes.
- FR-1.6 Account picker populated from `GET /accounts`; auto-select if exactly one.
- FR-1.7 Zone picker populated from `GET /zones`; auto-select if exactly one.
- FR-1.8 Subdomain field with live preview `m4.zone.com`; default value `m4`.
- FR-1.9 cloudflared check step: detect at `/opt/homebrew/bin/cloudflared`, `/usr/local/bin/cloudflared`, custom path; if absent, show install command (`brew install cloudflared`) with copy button.

#### FR-1.5 — Dashboard (D-Refit, 2026-04-30)
The Dashboard is the primary user-facing window — fuses status + control + inline configuration in one 800×560 surface. See `UX-GAP-ANALYSIS.md §3` for the full mockup. Core sections: header (logotype + state pill), hero hostname (large + ssh command + edit/copy/username buttons), QR code card (CIQRCodeGenerator, brand-tinted), live metrics card (cloudflared `127.0.0.1:20241/metrics`), recent activity scroll (last 50 of 500-line ring buffer from cloudflared stderr), network row (NWPathMonitor + CWWiFiClient SSID + localhost:22 SSH probe), footer action row (Stop/Restart/Settings/Diagnostics).
- FR-1.5a Auto-opens at launch when API token exists and `prefs.openDashboardAtLaunch == true` (default).
- FR-1.5b "Open Dashboard…" appears at top of MenuBarExtra dropdown with `⌘D`.
- FR-1.5c Inline config: subdomain edit popover triggers `CloudflareClient.updateCNAME()` + `CloudflaredManager.restart()`; SSH-username edit popover only updates `PreferencesStore.sshUsername`.
- FR-1.5d Diagnostics sheet runs DNS + HTTPS probe against the configured hostname (10s timeout) and reports verdict + latency + HTTP code.
- FR-1.5e Hard cuts only on state changes per BRAND.md §7 (`withAnimation(.linear(duration: 0.16))`).

### 7.2 Tunnel Lifecycle
- FR-2.1 On wizard completion, create named tunnel via `POST /accounts/{aid}/cfd_tunnel` with name `cf-tunnel-menubar-<hostname>`.
- FR-2.2 Persist `tunnel_id` in UserDefaults; persist tunnel run token in Keychain under `cloudflare.tunnel.<tunnel_id>.token`.
- FR-2.3 Push ingress configuration via `PUT /cfd_tunnel/{tid}/configurations` with single rule: `service: ssh://localhost:<port>` (port default 22, configurable).
- FR-2.4 Catch-all rule `service: http_status:404` appended last (Cloudflare requirement).
- FR-2.5 Launch `cloudflared tunnel run --token <run_token>` as child Process; stream stdout + stderr through `Pipe`.
- FR-2.6 State machine: `.idle → .starting → .running(tunnelID, hostname) → .failed(Error) | .stopped`.
- FR-2.7 Quit signal: SIGTERM → wait 5s → SIGKILL; on app `applicationWillTerminate` and explicit Quit menu.
- FR-2.8 Restart action: stop → 1s settle → start with current config.

### 7.3 DNS Management
- FR-3.1 On tunnel create or subdomain change, ensure CNAME `<subdomain>.<zone> → <tunnel_id>.cfargotunnel.com` (proxied=true).
- FR-3.2 Idempotent: query `GET /zones/{zid}/dns_records?name=<fqdn>`; if exists with correct content, no-op; if exists with wrong content, `PUT` update; if absent, `POST` create.
- FR-3.3 On subdomain change, delete old record after new record verified.
- FR-3.4 Surface DNS propagation expectation in UI ("typically <60s for proxied records").

### 7.4 Menu Bar UI
- FR-4.1 Status icon: SF Symbol `network` filled (running, tinted accent), `network.slash` (stopped), animated rotation (connecting).
- FR-4.2 Menu sections (top to bottom):
  - Status block: state text, hostname, uptime
  - Quick actions: Copy SSH command, Copy hostname, Reconnect, Stop / Start
  - Settings…
  - Quit
- FR-4.3 Copy SSH command produces `ssh $(whoami)@<fqdn>`; user-overridable in Settings (custom username field).
- FR-4.4 Live state binding via `@Observable` — no manual refresh needed.

### 7.5 Settings Window
- FR-5.1 Tab: General — Launch at login (SMAppService), notifications toggle, log level picker.
- FR-5.2 Tab: Cloudflare — token re-entry (rotates Keychain), account picker, zone picker, "Verify Token" button.
- FR-5.3 Tab: Tunnel — tunnel name (read-only), tunnel ID (read-only with copy), local port (NumberField, 1–65535), Delete Tunnel button (with confirmation, removes from CF + DNS).
- FR-5.4 Tab: DNS — subdomain field, full FQDN preview, "Apply DNS Changes" button.
- FR-5.5 Tab: Advanced — `cloudflared` binary path picker, custom ingress YAML override (textarea, validated), live log viewer (last 1000 lines, OSLog-backed).

### 7.6 Reliability
- FR-6.1 `NWPathMonitor` observes default path; on `.unsatisfied → .satisfied` transition, schedule reconnect after 2s debounce.
- FR-6.2 `NSWorkspace.willSleepNotification`: graceful stop. `didWakeNotification`: 3s delay → restart.
- FR-6.3 Exponential backoff on tunnel-run failures: 2s, 4s, 8s, 16s, 30s (capped). Reset on successful connection ≥ 30s.
- FR-6.4 Surface `UNNotification` on: tunnel up after downtime, repeated failures (≥3 in window), token revoked.

### 7.7 Logging
- FR-7.1 OSLog subsystem `com.krzemienski.burrow`; categories: `tunnel`, `cloudflare`, `network`, `ui`, `keychain`, `lifecycle`.
- FR-7.2 No secret values logged at any level (token, run token, full DNS API responses scrubbed).
- FR-7.3 Documented `log show` predicate for support: `log show --predicate 'subsystem == "com.krzemienski.burrow"' --last 1h`.

### 7.8 Notifications (D-Refit, 2026-04-30 — was stub)
The Notifier (`Sources/Notifications/Notifier.swift`) is **wired** end-to-end against `UNUserNotificationCenter`. Permission is requested at launch via `AppDelegate.applicationDidFinishLaunching`. Categories registered: `BURROW_TUNNEL_UP`, `BURROW_TUNNEL_DOWN`, `BURROW_RECONNECTING`, `BURROW_TOKEN_REVOKED`, `BURROW_SCOPE_MISSING`, `BURROW_FIRST_SUCCESS`. Each category has matching action buttons (Copy SSH, Restart, Open Dashboard, Open Settings, Open Cloudflare Dashboard).

| Event | Body | Sound | Action |
|-------|------|-------|--------|
| Tunnel up | "<host> is live. ssh <user>@<host>" | none | Copy SSH |
| Tunnel down | "Tunnel stopped. Click to restart." | none | Restart |
| Reconnecting | "Lost connection. Reconnecting (attempt N)…" | none | Open Dashboard |
| Token revoked | "Cloudflare token revoked. Re-enter in Settings." | Submarine | Open Settings → Cloudflare |
| Insufficient scope | "Token missing scope: <missing>. Re-create token." | Submarine | Open dash.cloudflare.com |
| First success after wizard | "Burrow ready. Try it: ssh <user>@<host>" | Glass | Copy SSH |

Notifications are gated by `PreferencesStore.shared.notificationsEnabled` (default true). Action buttons bridge through `NotificationCenter.default` to the SwiftUI scene graph (see `BurrowOpenWindowBridge` in `Sources/App/CFTunnelApp.swift`).

---

## 8. Non-Functional Requirements

### 8.1 Security
- NFR-S1: API token stored only in Keychain, accessibility class `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- NFR-S2: Tunnel run token stored separately in Keychain (rotatable independently).
- NFR-S3: No credential ever written to disk outside Keychain (no plist, no JSON file, no log).
- NFR-S4: All Cloudflare API calls over HTTPS with cert validation (no `URLSessionDelegate` cert overrides).
- NFR-S5: App signed with Developer ID, hardened runtime, notarized for distribution.
- NFR-S6: Entitlements minimal: `com.apple.security.network.client` only (no full disk, no automation).

### 8.2 Performance
- NFR-P1: Cold launch to menu bar visible: < 1.5s.
- NFR-P2: Idle CPU: < 0.1% on M-series, < 0.3% on Intel.
- NFR-P3: Resident memory: < 50 MB excluding `cloudflared` child.
- NFR-P4: API client uses connection reuse; one `URLSession` per app lifetime.

### 8.3 Compatibility
- NFR-C1: macOS 13.0 Ventura minimum (for `MenuBarExtra` + `SMAppService`).
- NFR-C2: Apple Silicon native + Intel via Universal binary.
- NFR-C3: `cloudflared` ≥ 2024.x.x supported (validate version string on detect).

### 8.4 Accessibility
- NFR-A1: All menu items have accessibility labels.
- NFR-A2: Settings forms support keyboard navigation (tab order verified).
- NFR-A3: VoiceOver tested on all wizard steps and Settings tabs.

### 8.5 Distribution
- NFR-D1: Direct Developer ID download (DMG or .pkg).
- NFR-D2: Sparkle-based auto-update considered for v1.1; not required for v1.0.

---

## 9. Technical Architecture

### 9.1 Module Layout
```
cf-tunnel-menubar/
├── App/
│   ├── CFTunnelApp.swift           // @main, scene graph
│   └── AppDelegate.swift           // NSApplicationDelegate adapters
├── TunnelCore/
│   ├── CloudflaredManager.swift    // actor: process lifecycle, state machine
│   ├── IngressConfigBuilder.swift  // YAML generation
│   └── TunnelState.swift           // enum + observable wrapper
├── CloudflareAPI/
│   ├── CloudflareClient.swift      // actor: URLSession wrapper
│   ├── Endpoints.swift             // typed endpoints
│   ├── Models/                     // Codable: Zone, Tunnel, DNSRecord, TokenVerify
│   └── CloudflareError.swift
├── Keychain/
│   └── KeychainService.swift       // wraps KeychainAccess or Security framework
├── Preferences/
│   └── PreferencesStore.swift      // UserDefaults-backed @Observable
├── UI/
│   ├── MenuBar/
│   │   └── MenuBarContentView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── GeneralTab.swift
│   │   ├── CloudflareTab.swift
│   │   ├── TunnelTab.swift
│   │   ├── DNSTab.swift
│   │   └── AdvancedTab.swift
│   └── FirstRun/
│       ├── WizardCoordinator.swift
│       └── Steps/                  // 7 step views
├── Networking/
│   ├── NetworkMonitor.swift        // NWPathMonitor wrapper
│   └── PowerObserver.swift         // sleep/wake
├── Logging/
│   └── Log.swift                   // OSLog categories
└── Resources/
    └── Assets.xcassets
```

### 9.2 Data Flow
```
[FirstRun Wizard]
  ↓ writes token
[Keychain] ← [CloudflareClient] → [Cloudflare API]
                    ↓ tunnel_id + run_token
                    ↓ ingress config
            [CloudflaredManager]
                    ↓ launches
              [cloudflared child]
                    ↓ stdout/stderr
            [TunnelState @Observable]
                    ↓
              [MenuBar UI]

[NetworkMonitor] ─┐
[PowerObserver]  ─┴→ [CloudflaredManager.reconnect()]
```

### 9.3 Key Dependencies (candidates — finalize in research phase)
| Purpose | Candidate | Fallback |
|---------|-----------|----------|
| Keychain | `KeychainAccess` (kishikawakatsumi) | Native `Security` framework |
| Logging | `OSLog` (native) | — |
| Launch at login | `SMAppService` (native, macOS 13+) | `LaunchAtLogin-Modern` (sindresorhus) |
| HTTP | `URLSession` (native) | — |
| YAML | `Yams` | hand-rolled (config is simple enough) |

---

## 10. cloudflared Distribution Strategy

### 10.1 Decision: Detect-or-Guide (not bundle)
| Path | Action |
|------|--------|
| `/opt/homebrew/bin/cloudflared` (Apple Silicon Homebrew) | Use directly |
| `/usr/local/bin/cloudflared` (Intel Homebrew or pkg install) | Use directly |
| Custom path in Settings | Use directly |
| None found | Wizard shows `brew install cloudflared` with copy button + link to Cloudflare downloads page |

### 10.2 Rationale
- Bundling adds ~30 MB to app size and creates upgrade lag.
- Cloudflared releases frequently; Homebrew tracks upstream within hours.
- Detect-or-guide keeps app ≤ 10 MB and offloads update responsibility.

### 10.3 Version Probe
On detect, run `cloudflared --version`; parse semver; warn (non-blocking) if < documented minimum.

---

## 11. Validation Plan (No Mocks — Real Cloudflare Account)

### 11.1 Acceptance Tests (manual, evidence-captured)
| ID | Scenario | Evidence |
|----|----------|----------|
| AT-1 | Fresh install, complete wizard < 5 min | Screen recording timestamped |
| AT-2 | SSH from mobile hotspot reaches local Mac | Terminal recording, both ends |
| AT-3 | API token verify with insufficient scope shows exact missing scope | Screenshot |
| AT-4 | Subdomain change updates DNS, old record removed | `dig` before/after, CF dashboard screenshot |
| AT-5 | Sleep 30 min → wake → SSH works within 15s | Timestamped log + SSH attempt |
| AT-6 | WiFi off → on → tunnel reconnects within 30s | OSLog trace |
| AT-7 | Quit app → no orphan `cloudflared` process | `ps aux \| grep cloudflared` empty |
| AT-8 | Token revoked externally → app surfaces auth error within 60s | Notification screenshot |
| AT-9 | 24h soak: tunnel up ≥ 99% with ≥ 3 sleep cycles | OSLog uptime histogram |
| AT-10 | Memory < 50 MB after 24h | Activity Monitor screenshot |

### 11.2 Validation Gates (Iron Rules)
- No mocks, no test files, no `XCTest` targets.
- No simulated Cloudflare responses — real API only.
- Every PASS verdict cites a specific evidence file under `e2e-evidence/<scenario>/`.
- Empty files = invalid evidence.

---

## 12. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cloudflare API schema drift | Low | High | Pin to dated API version where possible; integration tests against live API monthly |
| `cloudflared` flag breaking change | Med | High | Version probe + minimum-version warn; document override path |
| User pastes token with wrong scopes | High | Med | Pre-populate scope list in token-create deep link; verify post-paste with explicit diff |
| App Sandbox blocks subprocess | High | High | Ship non-sandboxed Developer ID build for v1.0; sandbox refactor in v1.2 |
| DNS record collision (subdomain in use) | Med | Med | Detect existing record on apply; offer "overwrite" or "choose different subdomain" |
| Keychain locked after reboot before login | Low | Med | Use `AfterFirstUnlock` accessibility; defer tunnel start until Keychain readable |
| User has multiple zones, picks wrong one | Med | Low | Show full zone domain in picker; require explicit confirm in wizard |
| `cloudflared` zombie on app crash | Low | Med | Register child PID; on launch, scan for orphans matching tunnel name and reap |

---

## 13. Open Questions (resolve before code)

1. Sandbox or no? Subprocess control is fraught under sandbox; recommendation = **non-sandboxed Developer ID** for v1.0.
2. Bundle Yams or hand-write YAML? Ingress config has 3 fields — recommendation = **hand-write**.
3. Single vs multi-tunnel storage in v1.0? Recommendation = **single tunnel, multi in v1.1** (requires schema versioning in UserDefaults now).
4. Custom username for SSH command — store per-tunnel or global? Recommendation = **global** for v1.0.
5. Auto-update mechanism — Sparkle now or v1.1? Recommendation = **v1.1**.

---

## 14. Milestones

| Milestone | Scope | Target |
|-----------|-------|--------|
| M0 — Research complete | llms.txt ingested, dependencies pinned, sandbox decision logged | Day 1 |
| M1 — Skeleton | Xcode project, MenuBarExtra renders, Settings empty tabs | Day 2 |
| M2 — API client | All 11 endpoints typed + tested against real CF account | Day 4 |
| M3 — Tunnel lifecycle | `cloudflared` launched, state machine wired | Day 6 |
| M4 — Wizard | All 7 steps functional end-to-end | Day 8 |
| M5 — Reliability | Network monitor + sleep/wake + backoff | Day 9 |
| M6 — Polish + AT pass | All acceptance tests green with evidence | Day 11 |
| M7 — Notarized DMG | Signed, notarized, downloadable | Day 12 |

---

## 15. Documentation Sources (binding references)

### Cloudflare (llms.txt format — ingest into Serena MCP)
- Master: `https://developers.cloudflare.com/llms.txt`
- Tunnel: `https://developers.cloudflare.com/tunnel/llms.txt`
- Tunnel full: `https://developers.cloudflare.com/tunnel/llms-full.txt`
- Cloudflare One: `https://developers.cloudflare.com/cloudflare-one/llms.txt`
- Fundamentals (API tokens): `https://developers.cloudflare.com/fundamentals/llms.txt`
- DNS: `https://developers.cloudflare.com/dns/llms.txt`
- API v4 reference: `https://developers.cloudflare.com/api/`

### High-value pages
- Configuration file: `https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/`
- Service on macOS: `https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/as-a-service/macos/`
- SSH with cloudflared: `https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/`
- Token creation: `https://developers.cloudflare.com/fundamentals/api/get-started/create-token/`
- `cloudflared` repo: `https://github.com/cloudflare/cloudflared`

### Apple (via llm.codes)
- MenuBarExtra: `https://llm.codes/?url=https://developer.apple.com/documentation/swiftui/menubarextra`
- SMAppService: `https://llm.codes/?url=https://developer.apple.com/documentation/servicemanagement/smappservice`
- Keychain Services: `https://llm.codes/?url=https://developer.apple.com/documentation/security/keychain_services`
- NWPathMonitor: `https://llm.codes/?url=https://developer.apple.com/documentation/network/nwpathmonitor`
- Process: `https://llm.codes/?url=https://developer.apple.com/documentation/foundation/process`
- OSLog: `https://llm.codes/?url=https://developer.apple.com/documentation/os/oslog`

---

## 16. Out of Scope (explicit)

- Windows / Linux ports.
- HTTP / RDP / VNC / arbitrary TCP ingress.
- Multi-tunnel UI.
- Cloudflare Access policy authoring.
- Team / Zero Trust org switcher.
- Built-in SSH client.
- Bundled `cloudflared` updater.
- iCloud / cross-device sync.
- Telemetry / analytics.

---

## 17. Approval

| Role | Name | Status |
|------|------|--------|
| Product owner | Nick Krzemienski | Pending |
| Tech lead | TBD | Pending |
| Security review | TBD | Pending |

---

## 18. Brand Identity (locked v1.1)

The product name is **Burrow**. The codename `cf-tunnel-menubar` is retained for the repository directory, the run-token Keychain prefix, and the OSLog identifier root only — every user-facing surface uses the locked name.

### 18.1 Authoritative document

`BRAND.md` is the single source of truth for visual identity. Any change to colors, typography, voice, motion, or iconography MUST update `BRAND.md` first; downstream code follows.

### 18.2 Identity summary

| Token | Value |
|-------|-------|
| Product name | `Burrow` |
| Tagline | "Your machine, teleported." |
| Bundle ID | `com.krzemienski.burrow` |
| OSLog subsystem | `com.krzemienski.burrow` |
| Tunnel name template | `burrow-<hostname>` |
| Primary palette | Hybrid Black Bean (`#0E0907 → #4A3526` espresso surfaces, `#F5E9D7` cream text) |
| Primary accent | Cyber Orange `#FF6A1A` (active states, menu icon when running) |
| Hover / active | `#FF8838` |
| Press / deep border | `#E54A00` |
| Highlight / pulse | `#FFB85A` |
| Failure | Magenta `#FF1F6D` |
| Success pip | Acid `#C8FF1A` |
| Display font | Space Grotesk 700 |
| Mono / labels | JetBrains Mono 400/500/600 |
| Aesthetic | flat · hyper · brutalist; hard cuts; neon glow only; no soft gradients; no glassmorphism |

### 18.3 Brand asset deliverables (Phase 9 ship)

- `brand/logo-mark.svg` (primary + inverse)
- `brand/logo-wordmark.svg`
- `brand/app-icon-{1024,512@2x,256,128,64,32,16}.png`
- `brand/menubar-icon-template.svg` (monochrome macOS template image)
- `brand/social-card-1200x630.png`
- `Resources/Assets.xcassets/AppIcon.appiconset/` populated
- `Resources/Assets.xcassets/AccentColor.colorset/` set to `#FF6A1A`
- `Resources/Assets.xcassets/MenuBarIcon.imageset/` template variants

### 18.4 Voice & tone

| Say this | Never this |
|----------|------------|
| "tunnel up." 4h 12m | "successfully established secure connection!" |
| "missing scope: zone:dns:edit" with copy button | "oops! something went wrong." |
| "install with `brew install cloudflared`" — verbatim | "lightning fast" / "blazingly secure" / "enterprise grade" |
| "token revoked" + one-click re-enter | emoji in error states (🚀 🎉 ⚡ ❌) |
| "reconnecting in 4s" with attempt counter | marketing voice in the menu — show the SSH command instead |

### 18.5 Motion contract

| Motion | Timing | Use |
|--------|--------|-----|
| State changes | 160 ms · `steps(2)` | Hard cut between running / connecting / stopped / failed |
| Connecting pulse | 1.0 s · `steps(2)` infinite | Two-frame opacity blink during reconnect |
| Running glow | static | Running state never animates |
| Success flash | 240 ms · ease-out | First-connection acid-green halo, one-shot |
| Failure shake | 320 ms · 3 cycles | Menu icon shifts ±2 px on auth failure |
| Reduced motion | 0.01 ms | Respect `prefers-reduced-motion` — collapse all to instant |

---

## 19. Static Site + Documentation (in scope, v1.0 ship)

The Burrow distributable v1.0 ships **three artifacts**, not one: the macOS app, the marketing site, and the docs site. All three share the brand and ship together.

### 19.1 Marketing site — `burrow.hack.ski`

Single-page static site. Public landing for the project.

| Section | Content |
|---------|---------|
| Hero | Wordmark + tagline; one-sentence value prop; download button (DMG link) |
| Demo | Animated GIF or short MP4 of the menu-bar icon transitioning idle → running, with the SSH command being copied |
| How it works | 3-step illustration: paste token · pick subdomain · ssh from anywhere |
| Why Burrow | Comparison strip vs Bore / ngrok / localtunnel — stable hostname, single trust anchor, free tier |
| Requirements | macOS 13+ · Cloudflare account with one zone · `brew install cloudflared` |
| Footer | GitHub link · docs link · brand mark · changelog link |

Build: static HTML/CSS only (no framework). Brand tokens via CSS custom properties match `BRAND.md` § 3 verbatim. No JavaScript above what the demo asset requires.

Deploy target: Cloudflare Pages, project name `burrow-site`, custom domain `burrow.hack.ski` (CNAME `burrow.hack.ski` → `<pages-project>.pages.dev`, proxied true).

### 19.2 Documentation site — `docs.hack.ski/burrow` (or `burrow.hack.ski/docs`)

Public docs surface. The macOS app links here from Settings → General → "Open documentation".

| Section | Content |
|---------|---------|
| Quick start | 5-minute walkthrough mirroring the in-app wizard |
| Cloudflare token guide | Required scopes (4) verbatim with copy buttons; screen-grabs of the token-create page |
| First-run wizard | 7 steps with screenshots from `e2e-evidence/phase-06/` |
| Settings reference | Per-tab walkthrough (General, Cloudflare, Tunnel, DNS, Advanced) |
| Troubleshooting | Token revoked · cloudflared not found · DNS collision · sleep/wake hang · WiFi flap recovery |
| FAQ | Why not bundle cloudflared? Why not sandboxed? Multi-tunnel coming when? |
| Changelog | Per-version entry, linked from menubar app About |
| Brand | Color tokens, typography, logo download bundle (for press) |

Build: same static stack as the marketing site, with a left-rail nav and prose-optimized typography per `references/css-patterns.md` "Prose Page Elements". Search via static `lunr`-style index (no third-party search service for v1.0).

Deploy target: Cloudflare Pages, project name `burrow-docs`, custom domain per the routing decision below.

### 19.3 Routing decision (open)

Two options:

- **A — separate subdomains:** `burrow.hack.ski` (marketing) + `docs.hack.ski/burrow` (docs nested in a multi-product docs zone). Better long term if more `hack.ski` products ship.
- **B — single subdomain:** `burrow.hack.ski` for marketing, `burrow.hack.ski/docs` for docs. One Pages project, one CNAME. Simpler v1.0.

Recommendation: **B** for v1.0; revisit when a second `hack.ski` product needs docs.

### 19.4 Site assets repo layout

```
site/                              # marketing site
├── index.html
├── assets/
│   ├── styles.css
│   ├── demo.mp4
│   ├── og.png                     # 1200×630
│   └── favicon/
docs/                              # documentation site
├── index.html
├── quick-start.html
├── cloudflare-token.html
├── wizard.html
├── settings.html
├── troubleshooting.html
├── faq.html
├── changelog.html
├── brand.html
└── assets/
    ├── styles.css                 # shares brand tokens with site/
    ├── search-index.json
    └── search.js
```

Both directories live in this repo, not a separate one — keeps the brand source of truth co-located with the app it markets.

### 19.5 Acceptance tests for site + docs

Adds three new ATs to PRD § 11.1 (numbering continues from existing AT-1 → AT-10):

| ID | Scenario | Evidence |
|----|----------|----------|
| AT-11 | `burrow.hack.ski` returns 200 with brand-correct hero (cyber-orange on bean, Space Grotesk display, wordmark visible) | `curl -I` + Lighthouse perf ≥ 90, screenshot diff vs `~/.agent/diagrams/burrow-brand-kit.html` hero section |
| AT-12 | `burrow.hack.ski/docs/quick-start` renders with left-rail nav and zero JavaScript console errors | Browser screen recording + `console.log` capture |
| AT-13 | App's Settings → General → "Open documentation" opens the live docs URL | Screen recording, click → browser open, hostname matches `docs.hack.ski/burrow` or `burrow.hack.ski/docs` |

### 19.6 Out of scope for v1.0 site/docs

- CMS / admin surface — site is hand-edited HTML
- A/B testing infrastructure
- Analytics beyond Cloudflare's built-in Web Analytics (privacy-preserving, no cookies)
- Localization / i18n — English only
- Comments / discussion (point users to GitHub Issues)

---

## 20. Security Notice — credential handling

### 20.1 Operating principle

Burrow exists because credentials shouldn't end up in shell history, dotfiles, screenshots, chat transcripts, or markdown files. The single trust anchor is the macOS Keychain; everything else is a thin client over it.

### 20.2 Concrete rules

- **Never** paste a real Cloudflare API token into chat, email, a PR description, a screenshot, an OSLog message, or any file in this repository — including `.env`, `.env.local`, `secrets.json`, comments, or example commands. The PRD/PRP/BRAND/README never embed a real token.
- **Always** use a scratch token for development; rotate it after every demo, after sharing a screen, and after any credential exposure.
- **`cloudflared --token <run_token>`** lines must be scrubbed (`--token \S+` → `--token <REDACTED>`) before they reach OSLog.
- **API token** lives at Keychain key `cloudflare.api.token`, accessibility `kSecAttrAccessibleAfterFirstUnlock`.
- **Tunnel run tokens** live at `cloudflare.tunnel.<tunnel_id>.token`, accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **No `URLSessionDelegate`** ever overrides certificate validation. Burrow trusts the system trust store and nothing else.

### 20.3 Incident response

If a token is exposed (via chat, screenshot, accidental commit, etc.):

1. Open https://dash.cloudflare.com/profile/api-tokens.
2. Click **Roll** on the affected token (or **Delete** + create new).
3. Re-enter the new token via Burrow's Settings → Cloudflare → Re-enter.
4. The old token's run tokens are invalidated server-side; rotate them via `GET /accounts/{aid}/cfd_tunnel/{tid}/token` and store the new value in Keychain.
5. Note the incident in `e2e-evidence/incidents/<date>-<short-slug>.md` with no token values quoted.

### 20.4 Disclosure policy

If a third party finds a vulnerability in Burrow, point them at the GitHub Security tab. v1.0 does not commit to a published bug bounty; v1.1 may.

---

**End of PRD v1.1.0**
