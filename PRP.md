# Product Requirement Prompt (PRP)
## Burrow — Cloudflare Tunnel SSH Menu Bar (macOS)

**PRP Version:** 1.1.0
**Source PRD:** `/Users/nick/Desktop/cf-tunnel-menubar/PRD.md` (v1.1.0, 2026-04-30)
**Target Agent:** Claude Code / Cursor / equivalent autonomous coding agent
**Confidence Score (one-pass ship):** 8.5 / 10
**Generated:** 2026-04-30
**Product name:** Burrow
**Bundle ID:** `com.krzemienski.burrow`
**Acceptance hostname:** `m4.hack.ski`
**Brand authority:** `BRAND.md`

> A PRP is the minimum viable packet an AI needs to ship production-ready code on the first pass.
> PRD answers *what* and *why*. PRP adds *exactly how, with exactly which APIs, against exactly which guard-rails*.

---

## §0 — Goal

Build a notarized macOS 13+ menu bar application named **Burrow** (codename `cf-tunnel-menubar`) that:

1. Accepts a single Cloudflare API token (Keychain-stored).
2. Creates a **named** Cloudflare Tunnel via CF API v4.
3. Provisions a stable CNAME `<subdomain>.<zone>` → `<tunnel_uuid>.cfargotunnel.com`.
4. Manages `cloudflared tunnel run` as a child process with ingress `ssh://localhost:22`.
5. Auto-recovers across network changes and sleep/wake.
6. Lets the user copy `ssh user@<subdomain>.<zone>` from a one-click menu.

**Plus** ship two static surfaces alongside the app (PRD §19):
7. **Marketing site** at `burrow.hack.ski` — single-page static landing with hero, demo, how-it-works, comparison, requirements, footer.
8. **Documentation site** at `burrow.hack.ski/docs` (or `docs.hack.ski/burrow`) — quick start, token guide, wizard walkthrough, settings reference, troubleshooting, FAQ, changelog, brand.

**Definition of Done:** A user on a fresh Mac with a Cloudflare account, the `hack.ski` zone (or any zone they control), and `brew install cloudflared` completes Burrow setup in under 5 minutes and SSHes from a mobile hotspot to their local Mac at **`m4.hack.ski`** (the v1.0 acceptance hostname; any `<subdomain>.<zone>` works the same way). All 13 acceptance tests in PRD §11.1 + §19.5 pass with captured evidence under `e2e-evidence/`.

---

## §1 — Why

| Pain | Root cause | This app's fix |
|------|-----------|----------------|
| Inbound SSH blocked behind NAT/CGNAT | ISP topology | Cloudflare Tunnel = outbound-only QUIC |
| Dynamic IPs invalidate `~/.ssh/known_hosts` | DHCP / ISP | Stable hostname (`m4.domain.com` never moves) |
| Bore/ngrok hostnames change per session | Ephemeral by design | **Named** tunnel = stable UUID for life of tunnel |
| `cloudflared` setup needs YAML + plist + CLI | Power-user tooling | One-token wizard, no YAML touched |
| Credentials end up in dotfiles / shell history | No GUI for secrets | Keychain only, ever |

**Strategic value:** Removes Bore/ngrok from the personal infra stack. Single trust anchor (Cloudflare). Free tier covers all v1.0 use cases.

---

## §2 — What (User-Visible Behavior)

### 2.1 Happy Path
1. User downloads notarized DMG, drags to `/Applications`, launches.
2. App appears in menu bar (no Dock icon — `LSUIElement = YES`) **and** the SwiftUI scene graph registers a Dashboard `Window(id: "dashboard")` scene plus a Settings scene (D-Refit, 2026-04-30 — was MenuBarExtra-only).
3. First-run wizard opens automatically (7 steps, see PRD §FR-1.1 → §FR-1.9).
4. User pastes API token → app verifies scopes → user picks zone + subdomain.
5. App creates tunnel, provisions DNS, launches `cloudflared`.
6. Menu bar icon turns from gray (`network.slash`) to accent-tinted (`network`).
7. User clicks menu → "Copy SSH command" → pastes into Terminal → connects.

### 2.2 Persistent Operation
- App runs in background indefinitely.
- `cloudflared` child process owned by app.
- On laptop sleep: tunnel stops gracefully.
- On wake: tunnel restarts within 10s.
- On WiFi switch: tunnel reconnects within 30s with exponential backoff.
- On app quit: tunnel terminated cleanly (SIGTERM → 5s → SIGKILL fallback).

### 2.3 Failure Modes (must be visible)
| Condition | UI signal | Notification |
|-----------|-----------|--------------|
| Token invalid | Red dot, Cloudflare tab | "API token rejected — re-enter in Settings" |
| Token missing scope | Red dot, scope diff shown | "Missing scope: Zone:DNS:Edit" |
| `cloudflared` not found | Wizard halts at step 5 | "Install with `brew install cloudflared`" |
| Network down | Yellow spinner | (none — silent reconnect) |
| ≥3 failures in 5 min window | Persistent banner | "Tunnel failing — check Advanced > Logs" |
| Token revoked externally | Red dot within 60s | "Token revoked — re-authorize" |

---

## §3 — Curated Context (the part that makes this a PRP, not a PRD)

### 3.1 Authoritative Documentation (read in this order)

#### Cloudflare (open every link before writing API code)
| URL | Why |
|-----|-----|
| https://developers.cloudflare.com/api/ | Master API v4 reference — endpoint shapes |
| https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/ | Tunnel concept overview |
| https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/ | Ingress rule schema (canonical) |
| https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/ | Client-side `~/.ssh/config` setup user must do |
| https://developers.cloudflare.com/fundamentals/api/get-started/create-token/ | Token creation flow + permission groups |
| https://developers.cloudflare.com/fundamentals/api/reference/permissions/ | **Exact** permission strings |
| https://github.com/cloudflare/cloudflared/blob/master/README.md | Binary CLI flags and version compatibility |
| https://developers.cloudflare.com/tunnel/llms-full.txt | Full archive — ingest into local docs cache |

#### Apple (use llm.codes for clean markdown)
| URL | Why |
|-----|-----|
| https://llm.codes/?url=https://developer.apple.com/documentation/swiftui/menubarextra | MenuBarExtra scene API (macOS 13+) |
| https://llm.codes/?url=https://developer.apple.com/documentation/servicemanagement/smappservice | Modern launch-at-login (replaces deprecated `SMLoginItemSetEnabled`) |
| https://llm.codes/?url=https://developer.apple.com/documentation/security/keychain_services | Keychain Services (use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) |
| https://llm.codes/?url=https://developer.apple.com/documentation/network/nwpathmonitor | Network reachability — avoid deprecated `SCNetworkReachability` |
| https://llm.codes/?url=https://developer.apple.com/documentation/foundation/process | `Process` — child lifecycle, Pipe, signal handling |
| https://llm.codes/?url=https://developer.apple.com/documentation/os/oslog | Unified logging — use over `print` and `swift-log` for native integration |
| https://llm.codes/?url=https://developer.apple.com/documentation/usernotifications | UNUserNotificationCenter — request authorization before first banner |

### 3.2 Required Cloudflare API Token Permissions (exact strings)

```
Account → Cloudflare Tunnel → Edit
Zone    → DNS               → Edit
Zone    → Zone              → Read
Account → Account Settings  → Read
```

Token-create deep link with prefilled scopes:
```
https://dash.cloudflare.com/profile/api-tokens
```
(CF does not currently support URL-prefilled scopes; show the four required strings on the wizard screen with one-click copy buttons next to each.)

### 3.3 Cloudflare API Endpoint Cookbook (every call this app makes)

> All requests: `Authorization: Bearer <token>`, `Content-Type: application/json`, base `https://api.cloudflare.com/client/v4`.

#### 3.3.1 Token verification
```http
GET /user/tokens/verify
→ 200 { "result": { "id": "...", "status": "active" }, "success": true }
→ 401 invalid token
```

#### 3.3.2 Account discovery
```http
GET /accounts
→ 200 { "result": [{ "id": "<account_id>", "name": "..." }], ... }
```

#### 3.3.3 Zone discovery
```http
GET /zones?per_page=50
→ 200 { "result": [{ "id": "<zone_id>", "name": "domain.com", "account": { "id": "..." } }], ... }
```

#### 3.3.4 Create named tunnel
```http
POST /accounts/{account_id}/cfd_tunnel
{
  "name": "cf-tunnel-menubar-<hostname>",
  "config_src": "cloudflare"
}
→ 200 { "result": { "id": "<tunnel_uuid>", "name": "...", "token": "<run_token_base64>" }, ... }
```

> **Critical:** `config_src: "cloudflare"` enables remote-managed config (we PUT ingress via API).
> If omitted, defaults to `local`, and ingress YAML must be on disk — DO NOT use local mode.

#### 3.3.5 Get tunnel run token (rotation / re-fetch)
```http
GET /accounts/{account_id}/cfd_tunnel/{tunnel_id}/token
→ 200 { "result": "<run_token_base64>", ... }
```

#### 3.3.6 Set ingress configuration (cloud-managed)
```http
PUT /accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations
{
  "config": {
    "ingress": [
      { "hostname": "<fqdn>", "service": "ssh://localhost:22" },
      { "service": "http_status:404" }
    ]
  }
}
→ 200 { "result": { ... }, "success": true }
```

> **Catch-all required:** Cloudflare API rejects ingress arrays whose last rule has a `hostname`. Last rule MUST be service-only.

#### 3.3.7 List tunnels (sanity / recovery)
```http
GET /accounts/{account_id}/cfd_tunnel?is_deleted=false
→ 200 { "result": [...], ... }
```

#### 3.3.8 Delete tunnel (uninstall flow)
```http
DELETE /accounts/{account_id}/cfd_tunnel/{tunnel_id}
→ 200 { "success": true }
```

> Tunnel must be stopped (no active connections) before delete succeeds. Implement: stop `cloudflared`, wait 10s, retry delete up to 3 times.

#### 3.3.9 DNS record CRUD
```http
GET /zones/{zone_id}/dns_records?name=<fqdn>&type=CNAME
POST /zones/{zone_id}/dns_records   { "type":"CNAME","name":"<fqdn>","content":"<tunnel_uuid>.cfargotunnel.com","proxied":true,"ttl":1 }
PUT  /zones/{zone_id}/dns_records/{id}  { ...same shape... }
DELETE /zones/{zone_id}/dns_records/{id}
```

> `ttl: 1` = automatic. `proxied: true` is mandatory for `cfargotunnel.com` targets.

### 3.4 Ingress YAML (for Advanced override path only — cloud-managed is default)

```yaml
tunnel: <tunnel_uuid>
credentials-file: /Users/<user>/.cloudflared/<tunnel_uuid>.json
ingress:
  - hostname: m4.domain.com
    service: ssh://localhost:22
  - service: http_status:404
```

### 3.5 cloudflared Process Invocation

**Cloud-managed (default):**
```bash
cloudflared tunnel run --token <run_token_base64>
```

**Local-managed (Advanced override only):**
```bash
cloudflared tunnel --config /path/to/config.yml run <tunnel_uuid>
```

**Version probe:**
```bash
cloudflared --version
# → cloudflared version 2025.x.x (built ...)
```

Parse semver from `version (\d+\.\d+\.\d+)` regex.

### 3.6 Known Gotchas (from upstream issues + implementer experience)

| Gotcha | Source | Mitigation |
|--------|--------|------------|
| `Process` blocks main thread on `pipe.fileHandleForReading.readDataToEndOfFile()` | Apple Forums | Use `readabilityHandler` closure for streaming reads |
| `cloudflared` writes to **stderr** for INFO logs (not stdout) | cloudflared #501 | Capture both pipes, route INFO to OSLog `.info`, lines containing `ERR` to `.error` |
| `SMAppService.register()` fails silently if app isn't in `/Applications` | Apple TN3127 | Detect bundle path; show "Move to Applications" prompt if elsewhere |
| `NWPathMonitor` cancellation deadlocks if not called on its assigned queue | NWPathMonitor docs | Cancel from same `DispatchQueue` used in `start(queue:)` |
| Keychain access fails first 1–2s after boot before user login keychain unlocks | rdar | Use `kSecAttrAccessibleAfterFirstUnlock`, retry with backoff on `errSecInteractionNotAllowed` |
| App Sandbox blocks `Process.launch()` for binaries outside the bundle | Apple docs | Ship **non-sandboxed** Developer ID build for v1.0 (PRD §13 Q1) |
| `MenuBarExtra(.window)` style does NOT support keyboard menu navigation; `.menu` does but limits SwiftUI views | SwiftUI release notes | Use `.menu` style for v1.0; revisit for advanced log viewer |
| Cloudflare API rate limit: 1200 req / 5 min per account | CF docs | Single `URLSession`, exponential backoff on 429, no polling loops |
| Tunnel `config_src` cannot be flipped from `local` to `cloudflare` after create | CF community | If existing tunnel is local, app must DELETE + recreate |
| `proxied: false` CNAME to `cfargotunnel.com` returns NXDOMAIN | CF docs | Always `proxied: true` |
| Quitting app via `NSApp.terminate` skips deinit on actors | Swift Concurrency | Register `applicationWillTerminate` in `AppDelegate`; explicitly `await` cloudflared shutdown |
| `cloudflared tunnel run --token ...` token contains JSON base64; do NOT log raw token | own | Scrub `--token \S+` from any captured command line in logs |
| `CWWiFiClient.shared().interface()?.ssid()` returns nil silently when Location services denied, on Ethernet, or radio off | own (D-Refit) | Treat as optional; never crash; hide SSID field when nil |
| Refactoring `actor CloudflaredManager` → `@MainActor @Observable class` breaks BurrowE2E CLI tool (which has no main runloop) | own (D-Refit) | Keep actor; add `TunnelStateObserver` mirror class that subscribes to actor's `stateStream()`/`logStream()` and republishes for SwiftUI |
| `try? await throws -> T?` flattens to `T?` (single Optional), not `T??` | Swift 5.5+ | A single `if let x = try? await foo()` already binds non-optional; do NOT add a redundant second `let` |
| `UserDefaults(suiteName:)` returns nil when suite name matches the app's own bundle identifier | macOS docs | Fall back to `.standard` for the Burrow.app target; the BurrowE2E CLI (different bundle id) keeps the suite-scoped store |

### 3.7 Project Structure (target tree — match exactly)

```
cf-tunnel-menubar/
├── cf-tunnel-menubar.xcodeproj/
├── Package.swift                    # if SPM, else inside .xcodeproj
├── Sources/
│   ├── App/
│   │   ├── CFTunnelApp.swift        # @main, MenuBarExtra + Settings scenes
│   │   └── AppDelegate.swift        # NSApplicationDelegate adapter
│   ├── TunnelCore/
│   │   ├── CloudflaredManager.swift # actor
│   │   ├── IngressConfigBuilder.swift
│   │   ├── TunnelState.swift        # enum, @Observable wrapper
│   │   └── BinaryLocator.swift      # detect /opt/homebrew/bin/cloudflared etc.
│   ├── CloudflareAPI/
│   │   ├── CloudflareClient.swift   # actor wrapping URLSession
│   │   ├── Endpoints.swift          # one func per endpoint in §3.3
│   │   ├── Models/
│   │   │   ├── Account.swift
│   │   │   ├── Zone.swift
│   │   │   ├── Tunnel.swift
│   │   │   ├── DNSRecord.swift
│   │   │   ├── TokenVerify.swift
│   │   │   └── APIEnvelope.swift    # generic { result, success, errors[] }
│   │   └── CloudflareError.swift
│   ├── Keychain/
│   │   └── KeychainService.swift
│   ├── Preferences/
│   │   └── PreferencesStore.swift   # @Observable, UserDefaults-backed
│   ├── Networking/
│   │   ├── NetworkMonitor.swift
│   │   └── PowerObserver.swift
│   ├── Logging/
│   │   └── Log.swift                # 6 OSLog categories (PRD §FR-7.1)
│   └── UI/
│       ├── MenuBar/
│       │   └── MenuBarContentView.swift
│       ├── Settings/
│       │   ├── SettingsView.swift   # TabView root
│       │   ├── GeneralTab.swift
│       │   ├── CloudflareTab.swift
│       │   ├── TunnelTab.swift
│       │   ├── DNSTab.swift
│       │   └── AdvancedTab.swift
│       └── FirstRun/
│           ├── WizardCoordinator.swift
│           └── Steps/
│               ├── WelcomeStep.swift
│               ├── TokenStep.swift
│               ├── AccountZoneStep.swift
│               ├── SubdomainStep.swift
│               ├── CloudflaredCheckStep.swift
│               ├── CreateTunnelStep.swift
│               └── DoneStep.swift
└── Resources/
    └── Assets.xcassets
```

### 3.8 Dependency Pin List (lock these versions in `Package.swift`)

```swift
dependencies: [
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    // No Yams in v1.0 — ingress YAML is hand-written when needed
    // No swift-log — OSLog is native
    // No LaunchAtLogin — SMAppService is native on macOS 13+
]
```

---

## §4 — Implementation Blueprint

> Execute phases **in order**. Each phase has a verifiable artifact.
> Do not begin a phase until prior phase's artifact is captured under `e2e-evidence/phase-NN/`.

### Phase 0 — Research & Lock-In (30 min)

```
TASK: Read every URL in §3.1.
TASK: Confirm cloudflared installed: `which cloudflared && cloudflared --version`
TASK: Confirm Cloudflare account + domain ready (zone visible at https://dash.cloudflare.com)
TASK: Create scratch API token with the 4 scopes; verify `curl -H "Authorization: Bearer $T" https://api.cloudflare.com/client/v4/user/tokens/verify`
ARTIFACT: e2e-evidence/phase-00/token-verify.json (real CF response)
```

### Phase 1 — Project Scaffold (60 min)

```
TASK: Create Xcode macOS App project, name `cf-tunnel-menubar`, language Swift, interface SwiftUI, lifecycle SwiftUI App
TASK: Set Deployment Target = macOS 13.0
TASK: Info.plist — add LSUIElement = YES (Bool true)
TASK: Capabilities — uncheck App Sandbox; verify Hardened Runtime ON; add `com.apple.security.network.client` entitlement (still needed under Hardened Runtime)
TASK: Add KeychainAccess SPM dependency, version 4.2.2
TASK: Replace ContentView with MenuBarExtra scene rendering "Hello, tunnel" Text
TASK: Build + run, confirm menu bar icon appears, no Dock icon

ARTIFACT: e2e-evidence/phase-01/menubar-screenshot.png
```

### Phase 2 — Cloudflare API Client (3–4 hr)

```
TASK: Create CloudflareAPI/Models/APIEnvelope.swift
       struct APIEnvelope<T: Decodable>: Decodable {
         let result: T?
         let success: Bool
         let errors: [APIError]
         let messages: [APIMessage]
       }
TASK: Implement CloudflareClient as actor wrapping single URLSession (ephemeral configuration)
TASK: Implement all 11 endpoints from §3.3 as async throws methods
TASK: Each method: encode body via JSONEncoder, decode via JSONDecoder with snake_case strategy
TASK: Map non-2xx → typed CloudflareError (.invalidToken, .insufficientScope, .rateLimited(retryAfter:), .notFound, .conflict, .upstream(message:))
TASK: 429 handling: read Retry-After header, sleep, single retry
TASK: Validate token-verify, accounts, zones against the real scratch token from Phase 0

ARTIFACT: e2e-evidence/phase-02/api-smoketest.log — real CF API responses for each endpoint
```

### Phase 3 — Keychain & Preferences (1 hr)

```
TASK: KeychainService — wrap KeychainAccess, service identifier "com.krzemienski.cftunnelmenubar"
TASK: API methods:
       func setAPIToken(_:) async throws
       func getAPIToken() async throws -> String?
       func deleteAPIToken() async throws
       func setRunToken(_ token: String, tunnelID: String) async throws
       func getRunToken(tunnelID: String) async throws -> String?
TASK: Use accessibility .afterFirstUnlockThisDeviceOnly for run tokens, .afterFirstUnlock for API token (survives without iCloud sync — never use ThisDeviceOnly variants if syncing... but we are NOT syncing, so ThisDeviceOnly is fine for API token too — pick AfterFirstUnlock for boot resilience)
TASK: PreferencesStore — @Observable class on UserDefaults
       Keys: selectedAccountID, selectedZoneID, selectedZoneName, subdomain, tunnelID, tunnelName, localPort, sshUsername, launchAtLogin, notificationsEnabled, logLevel, customCloudflaredPath
TASK: Round-trip every key via real keychain + UserDefaults; quit app, relaunch, confirm persistence

ARTIFACT: e2e-evidence/phase-03/persistence-relaunch.log
```

### Phase 4 — cloudflared Lifecycle Manager (4–5 hr)

```
TASK: BinaryLocator — try in order:
       1. PreferencesStore.customCloudflaredPath if set and exists+executable
       2. /opt/homebrew/bin/cloudflared
       3. /usr/local/bin/cloudflared
       4. PATH lookup via `which cloudflared` subprocess
TASK: TunnelState enum: .idle, .starting, .running(tunnelID, hostname, since: Date), .reconnecting(attempt:Int), .failed(Error), .stopped
TASK: CloudflaredManager actor:
       - Holds Process? (child)
       - Holds Pipes for stdout, stderr, stdin
       - @Observable state property
TASK: start(runToken:) async throws:
       - Locate binary
       - Build Process with arguments ["tunnel","run","--token",runToken]
       - Attach pipes; set readabilityHandler on each → forward to OSLog (scrub --token)
       - Run; transition state .starting → .running on first stderr line containing "Registered tunnel connection"
       - Exit observer: terminationHandler → state .failed if exitCode != 0 and not user-initiated stop
TASK: stop() async — send SIGTERM, wait 5s, SIGKILL if still alive, mark state .stopped
TASK: restart() async throws — stop + 1s + start
TASK: Validate against real CF tunnel created in Phase 2; SSH to localhost via the public hostname

ARTIFACT: e2e-evidence/phase-04/ssh-via-tunnel.log — real ssh session captured
```

### Phase 5 — UI: MenuBar + Settings (3–4 hr)

```
TASK: MenuBarContentView — bind to TunnelState; show:
       - State chip (Running / Reconnecting / Stopped / Failed)
       - Hostname text + copy button
       - "Copy SSH command" → NSPasteboard.general.setString("ssh \(prefs.sshUsername)@\(hostname)", forType: .string)
       - Start / Stop / Restart actions
       - Settings… (opens Settings scene)
       - Quit
TASK: MenuBarExtra icon: SF Symbol via Image(systemName:); switch on state:
       .running → "network" with .accentColor tint
       .reconnecting → "arrow.triangle.2.circlepath"
       else → "network.slash"
TASK: SettingsView — TabView with 5 tabs from PRD §FR-5
TASK: CloudflareTab — token SecureField, "Verify" button, account picker, zone picker
TASK: TunnelTab — name (read-only), tunnelID (read-only + copy), port NumberField, Delete button (with confirmation alert)
TASK: DNSTab — subdomain field with .onChange debounce, FQDN preview, "Apply" button
TASK: AdvancedTab — binary path picker (NSOpenPanel), log viewer (last 1000 lines from OSLog stream)
TASK: All forms keyboard-navigable, accessibility labels on every interactive element

ARTIFACT: e2e-evidence/phase-05/settings-tabs-screenshots/*.png (one per tab)
```

### Phase 6 — First-Run Wizard (3 hr)

```
TASK: WizardCoordinator — @Observable, holds current step + accumulated config
TASK: Auto-launch wizard if KeychainService.getAPIToken() == nil at app start
TASK: Each step view conforms to a Step protocol with .next() and .canAdvance binding
TASK: Step 5 (cloudflared check): if missing, show install snippet:
       brew install cloudflared
       (with copy button + link to https://github.com/cloudflare/cloudflared/releases)
TASK: Step 6 (create tunnel): show progress bar with substeps:
       a. Creating tunnel… (POST /cfd_tunnel)
       b. Storing run token in Keychain…
       c. Pushing ingress config… (PUT /configurations)
       d. Creating DNS record… (POST /dns_records)
       e. Launching cloudflared…
       f. Verifying connection… (wait for state .running, max 15s)
TASK: Wizard completion writes all prefs, dismisses window, leaves app in running state

ARTIFACT: e2e-evidence/phase-06/wizard-walkthrough.mov (screen recording, < 5 min duration)
```

### Phase 7 — Reliability (2 hr)

```
TASK: NetworkMonitor — wrap NWPathMonitor on its own DispatchQueue("network-monitor")
       Publish path satisfaction changes via @Observable; debounce 2s on transition into .satisfied
TASK: PowerObserver — register for NSWorkspace.shared.notificationCenter:
       .willSleepNotification → CloudflaredManager.stop() async
       .didWakeNotification → 3s delay → CloudflaredManager.start(runToken: …) async throws
TASK: Exponential backoff in CloudflaredManager: 2,4,8,16,30s capped; reset to 0 on connection ≥30s
TASK: SMAppService.mainApp register/unregister wired to PreferencesStore.launchAtLogin toggle
TASK: UNUserNotificationCenter requestAuthorization on first run; post on:
       - tunnel up after >5min downtime
       - ≥3 failures within 5min
       - token revoked (errSec / 401)

ARTIFACT: e2e-evidence/phase-07/wifi-flap-recovery.log + sleep-wake-recovery.log
```

### Phase 8 — Acceptance Tests (2–3 hr)

```
TASK: Execute all 10 tests from PRD §11.1 in order
TASK: Capture evidence per test under e2e-evidence/AT-NN/
TASK: Each test produces:
       - description.md (scenario, steps, expected vs observed)
       - artifact.{png,mov,log,json}
       - verdict.md (PASS / FAIL with cited artifact paths)
TASK: 24h soak test runs in background of normal use; capture uptime histogram from OSLog
```

### Phase 9 — Notarize & Ship (90 min)

```
TASK: Archive build (Product > Archive) with Developer ID Application cert
TASK: Notarize via xcrun notarytool submit --apple-id $AID --team-id $TID --password $PW --wait
TASK: Staple ticket: xcrun stapler staple cf-tunnel-menubar.app
TASK: Wrap in DMG via create-dmg or hdiutil
TASK: Verify Gatekeeper acceptance: spctl -a -t open --context context:primary-signature -vvv cf-tunnel-menubar.dmg

ARTIFACT: e2e-evidence/phase-09/notarization-receipt.json + final DMG
```

---

## §5 — Pseudocode Anchors (canonical patterns the agent must mirror)

### 5.1 Streaming a Process's stderr to OSLog without blocking
```swift
let proc = Process()
proc.executableURL = URL(fileURLWithPath: binaryPath)
proc.arguments = ["tunnel", "run", "--token", runToken]

let errPipe = Pipe()
proc.standardError = errPipe
errPipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
    let scrubbed = line.replacingOccurrences(
        of: #"--token \S+"#, with: "--token <REDACTED>", options: .regularExpression
    )
    Log.tunnel.info("\(scrubbed, privacy: .public)")
    // parse for state transitions
    if scrubbed.contains("Registered tunnel connection") {
        Task { await self.markRunning() }
    }
}
proc.terminationHandler = { p in
    Task { await self.handleExit(code: p.terminationStatus) }
}
try proc.run()
```

### 5.2 Cloudflare API call pattern (every endpoint follows this)
```swift
func createTunnel(accountID: String, name: String) async throws -> Tunnel {
    var req = URLRequest(url: base.appending(path: "accounts/\(accountID)/cfd_tunnel"))
    req.httpMethod = "POST"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONEncoder().encode([
        "name": name,
        "config_src": "cloudflare"
    ])
    let (data, resp) = try await session.data(for: req)
    return try decode(APIEnvelope<Tunnel>.self, data: data, response: resp).result!
}
```

### 5.3 SMAppService toggle (macOS 13+)
```swift
func setLaunchAtLogin(_ enabled: Bool) throws {
    let svc = SMAppService.mainApp
    if enabled {
        try svc.register()
    } else {
        try svc.unregister()
    }
}
// Status: SMAppService.mainApp.status (.enabled | .notRegistered | .requiresApproval | .notFound)
```

### 5.4 NWPathMonitor wrapper
```swift
@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.krzemienski.cftunnelmenubar.network")
    private(set) var isSatisfied: Bool = false

    func start(onTransition: @escaping (Bool) -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                if satisfied != self.isSatisfied {
                    self.isSatisfied = satisfied
                    onTransition(satisfied)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
```

---

## §6 — Validation Loops (Iron Rules — copy of PRD §11.2 + tighter gates)

### 6.1 Per-Phase Gates
```
After each phase:
  1. Run real-system check, not unit test
  2. Capture evidence file under e2e-evidence/phase-NN/
  3. If artifact empty (0 bytes) or absent → phase NOT complete
  4. Update e2e-evidence/inventory.txt with byte counts
```

### 6.2 No-Mock Mandate
- No `XCTest` targets created.
- No `MockCloudflareClient`, no `FakeProcess`, no fixtures.
- All API calls hit real `api.cloudflare.com`.
- All `cloudflared` invocations use the real binary against the real Cloudflare control plane.

### 6.3 Evidence Citation Format
Every PASS verdict in `e2e-evidence/phase-NN/verdict.md`:
```
- AT-N PASS — see e2e-evidence/AT-N/<artifact>.<ext> line N (or full file)
```

### 6.4 Acceptance Test Matrix (must all PASS)
| ID | Phase | Reuse PRD ref |
|----|-------|---------------|
| AT-1 | Phase 6 | PRD §11.1 |
| AT-2 | Phase 4 | PRD §11.1 |
| AT-3 | Phase 6 | PRD §11.1 |
| AT-4 | Phase 5 | PRD §11.1 |
| AT-5 | Phase 7 | PRD §11.1 |
| AT-6 | Phase 7 | PRD §11.1 |
| AT-7 | Phase 4 | PRD §11.1 |
| AT-8 | Phase 7 | PRD §11.1 |
| AT-9 | Phase 8 | PRD §11.1 |
| AT-10 | Phase 8 | PRD §11.1 |

### 6.5 Compilation ≠ Validation
A green build is **necessary** but **not sufficient**. Phase-N is complete only when:
- App launches without crash
- Real artifact captured against real services
- Evidence file > 0 bytes and contains the expected substring (e.g., `Registered tunnel connection`, `success: true`)

---

## §7 — Final Checklist (agent self-audit before declaring DONE)

### Architecture Conformance
- [ ] No third-party tunnel provider in code (no Bore, no ngrok, no localtunnel)
- [ ] Single Cloudflare API token is the only credential the user provides
- [ ] All Cloudflare API calls go through one `CloudflareClient` actor
- [ ] All `cloudflared` invocations go through one `CloudflaredManager` actor
- [ ] Module layout matches §3.7 exactly

### Security
- [ ] No secret values in OSLog at any level
- [ ] API token only in Keychain
- [ ] Tunnel run token only in Keychain
- [ ] No `URLSessionDelegate` overriding cert validation
- [ ] Hardened Runtime ON, Developer ID signed, notarized

### Cloudflare API Correctness
- [ ] Token verify called before any other endpoint
- [ ] Token scopes diffed against required 4 with explicit missing-scope UI
- [ ] All tunnels created with `config_src: "cloudflare"` (never `local`)
- [ ] All ingress arrays end with `{ "service": "http_status:404" }`
- [ ] All `cfargotunnel.com` CNAMEs created with `proxied: true`
- [ ] 429 handler reads Retry-After header
- [ ] Tunnel deletion preceded by `cloudflared` stop + 10s wait

### macOS Idioms
- [ ] `LSUIElement = YES` (no Dock icon)
- [ ] `MenuBarExtra` scene used (not custom `NSStatusItem`)
- [ ] `SMAppService.mainApp` for launch-at-login (not deprecated `SMLoginItemSetEnabled`)
- [ ] `NWPathMonitor` for connectivity (not `SCNetworkReachability`)
- [ ] `OSLog` for logging (not `print`, not `swift-log`)
- [ ] Sleep/wake via `NSWorkspace.shared.notificationCenter`
- [ ] Process termination handler reaps child cleanly
- [ ] `applicationWillTerminate` awaits cloudflared shutdown

### UX
- [ ] First-run wizard ≤ 5 minutes for non-CLI user (AT-1 evidence)
- [ ] All menu items keyboard-navigable
- [ ] All Settings forms have accessibility labels
- [ ] Error messages reference specific remediation (token scope, brew install, etc.)
- [ ] Copy-to-clipboard feedback visible (toast or icon flicker)

### Reliability
- [ ] WiFi flap → reconnect within 30s (AT-6 evidence)
- [ ] Sleep/wake → reconnect within 15s (AT-5 evidence)
- [ ] App quit → no orphan `cloudflared` (AT-7 evidence: `ps aux | grep cloudflared` empty)
- [ ] 24h soak ≥ 99% uptime (AT-9 evidence)
- [ ] Memory < 50 MB after 24h (AT-10 evidence)

### Evidence Tree
- [ ] `e2e-evidence/phase-00/` through `e2e-evidence/phase-09/` populated
- [ ] `e2e-evidence/AT-1/` through `e2e-evidence/AT-10/` populated
- [ ] `e2e-evidence/inventory.txt` lists every file with byte count
- [ ] `e2e-evidence/report.md` cites every PASS to a specific artifact

---

## §8 — Confidence Justification

**Score: 8.5 / 10** for one-pass production-ready ship.

**Why high:**
- All 11 Cloudflare API endpoints documented with exact request/response shapes.
- Apple framework choices pinned to native macOS 13+ APIs (no deprecated paths).
- 12 known gotchas pre-baked from upstream issues — agent will not hit them blind.
- Evidence-gated phase progression prevents declaring done on a green build.
- Real-system validation only — no mock layer to drift.

**Why not 10:**
- App Sandbox decision deferred (PRD §13 Q1) — agent must commit to non-sandboxed v1.0.
- `cloudflared` distribution path is detect-or-guide, not bundled — agent must handle the missing-binary UX flow with care.
- Notarization (Phase 9) requires Apple Developer credentials the agent cannot self-provision.

**Mitigations baked in:**
- §3.6 gotcha #6 explicitly resolves the sandbox question.
- §FR-1.9 + Phase 6 Step 5 explicitly handle missing binary.
- Phase 9 documents the exact `notarytool` invocation; user supplies creds.

---

## §9 — Agent Runbook (the literal commands)

```bash
# 0. Clone / scaffold
mkdir -p ~/Desktop/cf-tunnel-menubar && cd ~/Desktop/cf-tunnel-menubar

# 1. Pre-flight
which cloudflared || brew install cloudflared
cloudflared --version

# 2. Verify scratch token (replace $CF_TOKEN)
curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify | jq .

# 3. Discover account + zone
curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  https://api.cloudflare.com/client/v4/accounts | jq '.result[] | {id,name}'
curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  https://api.cloudflare.com/client/v4/zones | jq '.result[] | {id,name}'

# 4. Open Xcode, scaffold per Phase 1
open -a Xcode

# 5. Per phase: build, run, capture evidence
mkdir -p e2e-evidence/phase-{00..09} e2e-evidence/AT-{1..10}

# 6. Phase 9: notarize
xcrun notarytool submit cf-tunnel-menubar.zip \
  --apple-id $APPLE_ID --team-id $TEAM_ID --password $APP_SPECIFIC_PW --wait
xcrun stapler staple cf-tunnel-menubar.app
```

---

## §10 — Out-of-Band References (live docs to fetch at code-time)

The agent **must** open these via WebFetch / context7 / Cloudflare MCP at the moment it writes the corresponding code, not rely on training data:

- Cloudflare API reference for any endpoint touched
- `cloudflared` release notes (latest version's flag set)
- Apple `MenuBarExtra` docs (SwiftUI changes between macOS 13/14/15)
- `SMAppService` docs (entitlement and Info.plist requirements changed in macOS 14)

---

## §11 — Source PRD Cross-Reference

This PRP is a strict superset of `/Users/nick/Desktop/cf-tunnel-menubar/PRD.md`:

| PRD Section | PRP Section |
|-------------|-------------|
| §1 Executive Summary | §0 Goal + §1 Why |
| §2 Problem Statement | §1 Why |
| §3 Architecture Decision | §0 + §3.6 |
| §4 Goals & Non-Goals | §0 |
| §6 User Stories | §2 What |
| §7 Functional Requirements | §4 Implementation Blueprint |
| §8 Non-Functional Requirements | §6 + §7 Final Checklist |
| §9 Technical Architecture | §3.7 + §5 Pseudocode |
| §10 cloudflared Distribution | §3.6 + Phase 4 |
| §11 Validation Plan | §6 Validation Loops |
| §12 Risks & Mitigations | §3.6 Gotchas |
| §15 Documentation Sources | §3.1 |
| §18 Brand Identity (v1.1) | §13 Brand Integration |
| §19 Static Site + Docs (v1.1) | §12 Site & Docs Build |
| §20 Security Notice (v1.1) | §14 Security Posture |

---

## §12 — Static Site + Docs Build (v1.1 scope)

The marketing site and documentation site ship as part of v1.0. Both are static, both share the Burrow brand, both deploy to Cloudflare Pages.

### 12.1 Repo layout (extends §3.7)

```
site/
├── index.html                       single-page marketing
├── assets/
│   ├── styles.css                   imports brand/tokens.css
│   ├── demo.mp4                     menubar idle → running, ~6s loop
│   ├── og.png                       1200×630 social card
│   └── favicon/                     16, 32, 180, 192 PNG + .ico
docs/
├── index.html                       landing with left-rail nav
├── quick-start.html
├── cloudflare-token.html
├── wizard.html
├── settings.html
├── troubleshooting.html
├── faq.html
├── changelog.html
├── brand.html
└── assets/
    ├── styles.css                   imports brand/tokens.css
    ├── search-index.json            built from page bodies
    └── search.js                    lunr-style client-side
brand/
└── tokens.css                       single source of truth, generated from BRAND.md
```

### 12.2 Brand-token CSS contract

`brand/tokens.css` is the only place site + docs + (eventually) the macOS in-app web views read brand values from. Every site CSS file imports it via:

```css
@import url("/brand/tokens.css");
```

Token contents (verbatim from PRD §18.2 / `BRAND.md` §3):

```css
:root {
  --bean-0:  #050302;
  --bean-1:  #0E0907;
  --bean-2:  #170F0B;
  --bean-3:  #221610;
  --bean-4:  #2E1F16;
  --bean-5:  #4A3526;
  --cream:   #F5E9D7;
  --cream-2: #C9B7A1;

  --orange:        #FF6A1A;
  --orange-hot:    #FF8838;
  --orange-deep:   #E54A00;
  --orange-glow:   #FFB85A;

  --magenta: #FF1F6D;
  --acid:    #C8FF1A;
  --ice:     #18E0FF;

  --font-display: 'Space Grotesk', system-ui, sans-serif;
  --font-mono:    'JetBrains Mono', 'SF Mono', Consolas, monospace;
}
```

### 12.3 Marketing site phases (extends §4)

#### Phase S1 — Marketing scaffold (60 min)
Build `site/index.html` with all 6 sections from PRD §19.1. Hero + footer first, then mid-sections.
Artifact: `e2e-evidence/site/phase-S1/screenshot-light.png` + `screenshot-dark.png` (auto-detected from `prefers-color-scheme`; Burrow site is dark-only).

#### Phase S2 — Demo asset (45 min)
Record menubar transition idle → running with the SSH command being copied. Encode as `demo.mp4` (H.264, ≤ 800 KB) and as autoplay `<video muted loop playsinline>`. Fallback poster image.
Artifact: `e2e-evidence/site/phase-S2/demo.mp4` + a `frame-extract.png`.

#### Phase S3 — Lighthouse pass (30 min)
Run `lighthouse https://burrow.hack.ski` headless. Targets: perf ≥ 90, a11y = 100, best-practices ≥ 95, SEO ≥ 95.
Artifact: `e2e-evidence/site/phase-S3/lighthouse.json` + `lighthouse-summary.md`.

#### Phase S4 — Cloudflare Pages deploy (45 min)
Create Pages project `burrow-site`. Connect to this repo, build command empty, output dir `site/`. Add custom domain `burrow.hack.ski` via Pages UI; verify CNAME provisioning is automatic.
Artifact: `e2e-evidence/site/phase-S4/dns-record.json` + `pages-deploy.json` + a `curl -I https://burrow.hack.ski` capture.

### 12.4 Documentation site phases

#### Phase D1 — Docs scaffold + content (3 hr)
Author the 9 pages listed in PRD §19.2. Use prose-optimized typography per `references/css-patterns.md` "Prose Page Elements" — `--font-display` for h1–h3, system font for body, `--font-mono` for code, max-width 65ch.
Artifact: `e2e-evidence/docs/phase-D1/page-screenshots/` (one per page).

#### Phase D2 — Search index (45 min)
Build a static lunr-style index from page `<main>` bodies. Search box top-right, keyboard `/` to focus. No external service.
Artifact: `e2e-evidence/docs/phase-D2/search-recall.log` (3 sample queries with hit counts).

#### Phase D3 — Cloudflare Pages deploy (30 min)
Same as Phase S4 but for `docs.hack.ski/burrow` OR `burrow.hack.ski/docs` per PRD §19.3 routing decision.
Artifact: `e2e-evidence/docs/phase-D3/dns-record.json` + `curl -I` capture.

#### Phase D4 — In-app deep link (15 min)
Wire Settings → General → "Open documentation" to open the live docs URL via `NSWorkspace.shared.open(URL(string: ...))`.
Artifact: `e2e-evidence/docs/phase-D4/click-to-browser.mov`.

### 12.5 Site/docs acceptance tests (mirror PRD §19.5)

| ID | Phase | PRD ref |
|----|-------|---------|
| AT-11 | Phase S3 | §19.5 |
| AT-12 | Phase D1 | §19.5 |
| AT-13 | Phase D4 | §19.5 |

### 12.6 Site/docs do-not-do list

- No client-side JS framework (no React, no Vue, no Svelte). Hand-written HTML + CSS only. Demo `<video>` is the only JS-adjacent asset.
- No third-party fonts beyond `Space Grotesk` + `JetBrains Mono` (Google Fonts CDN, `display=swap`).
- No tracking pixels. Cloudflare Web Analytics (cookieless) is the only analytics surface.
- No build step that requires Node.js to be installed before deploy. The repo's HTML is the deployable; Pages serves it as-is.

---

## §13 — Brand Integration

### 13.1 In-app brand application

Where Burrow's UI must reflect the brand:

- **Menu-bar icon:** monochrome SF Symbol `network` template image, tinted `Color("AccentColor")` (resolves to `#FF6A1A`) when state is `.running`. `network.slash` when `.stopped`. `arrow.triangle.2.circlepath` when `.reconnecting`.
- **Settings window:** dark only — `bean-1` (`#0E0907`) background, `cream` (`#F5E9D7`) text. `Color("AccentColor")` for selected tab, action buttons, links.
- **Wizard:** same theme as Settings; large headline uses Space Grotesk if bundled, else SF Pro Display semibold.
- **Notifications:** title + body in default system style; do not attempt to colorize. Subtitle gets the SSH command verbatim when the tunnel comes up.

### 13.2 Asset pipeline

1. Author the marks once in `brand/source/burrow-mark.svg`.
2. Generate raster sizes via `iconutil`-style script (Phase 9):

```bash
sips -z 16 16   brand/source/burrow-mark.png --out Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png
sips -z 32 32   brand/source/burrow-mark.png --out Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png
# ... 32, 64, 128, 256, 512, 1024 variants per Contents.json
```

3. Menu-bar template image lives at `Resources/Assets.xcassets/MenuBarIcon.imageset/menubar.pdf` (preserves vectors, scales for Retina automatically).

### 13.3 Brand drift prevention

The CI pipeline (Phase 9 future work) compares `brand/tokens.css` `--orange` value against `Resources/Assets.xcassets/AccentColor.colorset/Contents.json` RGB. Drift between the two = build fail. Single source of truth enforced at the byte level.

---

## §14 — Security Posture

### 14.1 Iron rules (extends PRD §20)

- API token paths: `KeychainService.setAPIToken` → service `com.krzemienski.burrow`, account `cloudflare.api.token`, accessibility `.afterFirstUnlock`.
- Run token paths: `KeychainService.setRunToken(_:tunnelID:)` → account `cloudflare.tunnel.<tid>.token`, accessibility `.afterFirstUnlockThisDeviceOnly`.
- All log lines pass through a static `Log.scrub(_:)` helper that regex-strips `--token \S+`, `Authorization: Bearer \S+`, and any 32+ char hex sequence likely to be a token.
- The site and docs ship **with no credentials of any kind**. No `.env`, no example tokens, no "if your token is `abc123` then…" text. Examples use the literal placeholder `<YOUR_TOKEN>`.

### 14.2 Threat model

| Threat | Mitigation |
|--------|------------|
| Token in shell history | Burrow never asks the user to paste in a terminal — wizard-only |
| Token in chat / screenshot | Wizard's SecureField masks input; UI shows `••••••••` after save; no copy-back |
| Token in OSLog | `Log.scrub()` (above) |
| Token in disk backup | Keychain Services accessibility class prevents Time Machine inclusion of `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` items |
| Token in process memory dump | Out of scope for v1.0; v1.2 sandbox + memory-hardening work |
| Cert validation bypass | No `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` is implemented anywhere in the app — system trust store only |
| Run token reused after revocation | Server-side revocation is automatic when API token is rolled; UI surfaces the 401 within 60s (AT-8) |

### 14.3 Disclosure & rotation

- Any token suspected to be exposed → roll via dashboard, re-enter via Settings, document in `e2e-evidence/incidents/<date>-<slug>.md` (no token values).
- Project README links to GitHub Security advisories as the disclosure surface.

---

**End of PRP v1.1.0**
**Hand to agent. Ship in one pass.**
