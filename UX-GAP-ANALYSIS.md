# Burrow UX Gap Analysis & Dashboard Spec Proposal

**Date:** 2026-05-01
**Author:** Forge orchestrator (post-reflexion ruling)
**Trigger:** User killed 2 Burrow processes; pointed out absence of dashboard + lack of "rethink all different user experiences" + new directive: "use that dashboard and actually start certain things like how does the user configure certain things right when they open the application... executed and confirmed end-to-end just like we're going to do with the CLI perspective"
**Status:** PROPOSAL v2 — Dashboard as config-entry-point, end-to-end runtime-validated

---

## §1 — What Burrow currently has

| Surface | What | Compile | Runtime |
|---------|------|---------|---------|
| MenuBarExtra dropdown | `idle/Start Tunnel/Settings…/Quit Burrow` (+ hostname footnote, copy-SSH if hostname set) | ✅ | ✅ |
| Settings window | TabView w/ 5 tabs (General, Cloudflare, Tunnel, DNS, Advanced) | ✅ | ✅ |
| Welcome window (wizard) | 7 steps (Welcome → Token → Account/Zone → Subdomain → cloudflared check → Create tunnel → Done) | ✅ | ✅ steps 1+2 only |

**That's the entire UX surface.** No standalone window for "look at + control + configure the running tunnel." The user's mental model on first open is: "where do I see status and DO things?" Today's answer: tiny menubar icon. Insufficient.

## §2 — What's missing (UX gaps)

### Critical — Dashboard as primary surface

Burrow today is config-only (Settings) + setup-only (Wizard) + status-only (MenuBar). Missing: a single window that fuses **see + control + configure** so a returning user opens Burrow and immediately:

1. Sees the live tunnel state (big, glanceable).
2. Sees their hostname (large, copyable, QR-able).
3. Can change it without going to Settings (inline config-on-Dashboard).
4. Can start/stop/restart with one click.
5. Can see the recent log to know what's happening.
6. Can run a self-test ("is my tunnel actually reachable from outside?").
7. Gets notified when state changes (UNUserNotificationCenter wired).

The Dashboard is **the application**; everything else is supporting.

### Critical — Notifications

PRP §FR-7 mandates `UNUserNotificationCenter`. Currently STUB (AppDelegate.swift:24 says `// Phase 7: start NetworkMonitor + PowerObserver here.`). User has no way to know tunnel went down except by looking.

### Critical — Real-time metrics

cloudflared exposes Prometheus metrics at `127.0.0.1:20241/metrics` (proven in iter-2 cloudflared-stderr.log line 12). Burrow ignores it. Should surface: active connections, edge regions, bytes-in/out per minute, reconnect attempts.

### Critical — Log viewer

AdvancedTab has a "tunnel logs" placeholder ("— waiting for tunnel logs —") but no live-tail wired. CloudflaredManager.swift already has `Pipe.readabilityHandler`; the UI doesn't consume it.

### Important — End-to-end UI validation parity with CLI

User mandate: "executed and confirmed end-to-end just like we're going to do with the CLI perspective." Translation: the Dashboard's start/stop/configure flows must be **runtime-exercised via osascript** the same way `BurrowE2E` (CLI) exercises CloudflaredManager. AT-Dashboard MSCs must include real-button-click + real-state-transition + real-tunnel-up + real-SSH-attempt (using the dashboard's own affordances).

### Nice-to-have — Diagnostics + sharing

- "Test from outside" button (Cloudflare Worker echo)
- QR code of SSH cmd
- Latency probe to CF edge

---

## §3 — Proposed Dashboard layout (config + control + observe in one window)

ASCII mockup, **800×560** window, brand-strict (bean-1 background, cyber-orange accent):

```
┌──────────────────────────────────────────────────────────────────────┐
│  burrow                                              ●  RUNNING       │
│                                                    4h 12m up          │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  m4 . hack.ski                                       [edit]    │  │
│  │  ssh nick@m4.hack.ski                                [copy]    │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌──────────────────────┐  ┌────────────────────────────────────────┐│
│  │  [QR CODE]            │  │ EDGES   ACTIVE  ↓ MB    ↑ MB          ││
│  │  ░░░░░░░░░░░          │  │   4       1     12.3    3.4           ││
│  │  ░░ ░░░ ░░░           │  │ ewr×4   1 sess  /min   /min           ││
│  │  ░░░░░░░░░░░          │  └────────────────────────────────────────┘│
│  │  scan to ssh          │                                              │
│  └──────────────────────┘   Local SSH on port 22 — listening ✓       │
│                                                                        │
│  Recent activity                              [open in console]       │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │ 21:32:14  Registered tunnel connection ewr01                     ││
│  │ 21:32:13  Registered tunnel connection ewr05/ewr07/ewr16         ││
│  │ 21:32:12  Starting tunnel tunnelID=1d8c…                         ││
│  └──────────────────────────────────────────────────────────────────┘│
│                                                                        │
│  Network: en0 · Wi-Fi · online           [test from outside]          │
│  Current SSID: home-2.4G                                               │
│                                                                        │
│  [▎ Stop Tunnel]   [↻ Restart]   [⚙ Settings…]   [? Diagnostics]    │
└──────────────────────────────────────────────────────────────────────┘
```

**State-pill colors** (BRAND.md compliant):
- IDLE — `--bean-6` (dim brown)
- STARTING — `--orange-glow` w/ `steps(2)` blink
- RUNNING — `--acid` (`#C8FF1A` success pip)
- RECONNECTING — `--orange-hot` w/ `steps(2)` blink + attempt count overlay
- FAILED — `--magenta` (`#FF1F6D` alarm) w/ short error + `[?]` help link

**Inline configure on Dashboard:**
- `[edit]` next to subdomain → opens an inline popover w/ subdomain text-field + "Save" button → on save: `prefs.subdomain = X`, `CloudflareClient.updateCNAME()`, then `CloudflaredManager.restart()` automatically. No need to hop to Settings → DNS for the most common config edit.
- `[edit]` next to SSH-username → inline popover (same pattern).
- Local-port indicator clickable → opens Tunnel-tab in Settings window for port editor + advanced ingress.

**Live-updating fields (real bindings, no placeholders):**
- Uptime (1s ticker via Timer)
- Connection count + bytes (poll cloudflared metrics every 5s via `MetricsClient.swift`)
- Recent activity (live tail of CloudflaredManager pipe — last 50 lines, scrollable to last 500, ring buffer in CloudflaredManager actor)
- Network status (NetworkMonitor.swift — extend w/ SSID via CWWiFiClient on macOS 14+)

**Always-on actions:**
- Big copy-SSH button (cmd-C shortcut)
- QR code (CIQRCodeGenerator) of the full SSH cmd
- Stop / Restart (state-conditional, mirror MenuBar dropdown)
- Open Settings (cmd-,)
- Diagnostics (cmd-D)

## §4 — First-launch experience (Dashboard-first)

Today: app launches → MenuBarExtra appears → user has to discover Wizard via Window menu. New flow:

1. App launches.
2. AppDelegate checks `KeychainService.getAPIToken()` → if nil:
   - Auto-open Welcome wizard (Window scene "first-run") AT FRONT of any other window.
   - Dashboard window NOT presented yet (wizard owns the screen).
3. After wizard `Done` step (KeychainService.setAPIToken + tunnel/CNAME created):
   - Dismiss wizard.
   - Auto-open Dashboard window.
   - Dashboard immediately drives `CloudflaredManager.start(runToken:)`.
   - Dashboard shows STARTING state-pill, then animates to RUNNING when state-machine reports.
   - Notification fires: "Burrow ready. Try it: ssh nick@m4.hack.ski"
4. Subsequent launches:
   - If `prefs.openDashboardAtLaunch` (General-tab toggle, default `true`) → open Dashboard.
   - Else → menubar-only (current behavior).

This makes the Dashboard the FIRST thing a user sees when their setup is complete — answers "how does the user configure certain things when they open the application" by surfacing config inline.

## §5 — Proposed MenuBar dropdown enhancements

```
┌────────────────────────────┐
│  ● tunnel up · 4h 12m      │
│  m4.hack.ski               │
│  ──────────────            │
│  Open Dashboard…    ⌘D     │  ← NEW (top action)
│  Copy SSH command   ⌘C     │
│  ──────────────            │
│  Stop Tunnel        ⌘.     │
│  Restart Tunnel     ⌘R     │
│  ──────────────            │
│  Settings…          ⌘,     │
│  Quit Burrow        ⌘Q     │
└────────────────────────────┘
```

## §6 — Notifications spec (PRP §FR-7 wiring, mandatory now)

| Event | Body | Sound | Action |
|-------|------|-------|--------|
| Tunnel up | "m4.hack.ski is live. ssh nick@m4.hack.ski" | none | Copy SSH |
| Tunnel down | "Tunnel stopped. Click to restart." | none | Restart |
| Reconnecting | "Lost connection. Reconnecting (attempt 3)…" | none | Open Dashboard |
| Token revoked | "Cloudflare token revoked. Re-enter in Settings." | Submarine | Open Settings → Cloudflare |
| Insufficient scope | "Token missing scope: zone:dns:edit. Re-create token." | Submarine | Open dash.cloudflare.com |
| First success after wizard | "Burrow ready. Try it: ssh nick@m4.hack.ski" | Glass | Copy SSH |

## §7 — Implementation phases (Dashboard refit)

| Phase | Scope | Touch | LOC |
|-------|-------|-------|-----|
| D-A | Sources/UI/Dashboard/DashboardView.swift + state pill + uptime + hero hostname | NEW dir | ~250 |
| D-B | Inline config popovers (subdomain edit + ssh-username edit + auto-restart wiring) | NEW + edit | ~120 |
| D-C | CloudflaredManager log ring-buffer (replace placeholder + dashboard scroll) | edit CloudflaredManager.swift + NEW LogRingBuffer | ~100 |
| D-D | cloudflared metrics polling — Sources/Metrics/MetricsClient.swift | NEW | ~80 |
| D-E | QR code generator (CIQRCodeGenerator) inside DashboardView | NEW Sources/UI/Helpers/QRCode.swift | ~40 |
| D-F | UNUserNotificationCenter wiring per §6 | NEW Sources/Notifications/Notifier.swift + AppDelegate registration | ~150 |
| D-G | NetworkMonitor SSID/online indicator (CWWiFiClient) | edit Sources/Networking/NetworkMonitor.swift | ~50 |
| D-H | Auto-open Dashboard at first-launch + post-wizard | edit AppDelegate.swift + WizardCoordinator.swift | ~30 |
| D-I | CFTunnelApp.swift Scene addition (Window "Dashboard" id="dashboard") + MenuBarContentView "Open Dashboard…" item | edit | ~10 |
| D-J | "Test from outside" diagnostics (Cloudflare Worker echo or fallback to curl-from-self) | NEW Sources/Diagnostics/SelfTest.swift | ~60 |
| D-K | PRD §FR-1 + PRP §FR-2 + BRAND.md §6 + PHASES.md update for Dashboard scope | edit docs | ~200 |
| **Total** | | | **~1090 LOC** |

## §8 — End-to-end Dashboard validation (parity with BurrowE2E CLI)

The CLI E2E pattern: `setup → up → ssh-test → down → teardown` driven via osascript-equivalent commands.
The Dashboard E2E pattern (mirror): osascript-driven UI fan-out:

| Step | osascript action | Verifies |
|------|------------------|----------|
| 1 | Launch Burrow.app, wait for Welcome wizard window | Auto-launch wizard when no token |
| 2 | Type test token in Wizard step 2 → Continue → walk through all 7 steps using sshpass-paste of test data | Wizard E2E (closes MSC-6 fully) |
| 3 | Verify Welcome wizard auto-dismisses on Done | Coordinator dismiss contract |
| 4 | Verify Dashboard window auto-opens after Done | First-launch UX flow |
| 5 | osascript `entire contents` of Dashboard → assert state-pill, hostname, copy-SSH button present | Dashboard renders |
| 6 | Wait for state to transition to RUNNING (poll `entire contents` for state-pill text) | CloudflaredManager auto-started |
| 7 | Click "Copy SSH command" button via osascript → `pbpaste` to capture clipboard → assert matches `ssh nick@m4.hack.ski` | Copy-SSH flow |
| 8 | Spawn external ssh attempt via sshpass + cloudflared access ssh → capture sentinel | SSH-via-Dashboard E2E |
| 9 | Click subdomain `[edit]` → type "m4-test" → Save → wait for state to flip RECONNECTING → RUNNING | Inline config flow |
| 10 | Restore subdomain to "m4" + Save | Cleanup |
| 11 | Click "Stop Tunnel" → verify state pill goes IDLE | Stop-from-Dashboard |
| 12 | Quit Burrow → verify zero orphan cloudflared via pgrep | AT-7 (graceful shutdown) |

Evidence captured to `e2e-evidence/AT-Dashboard/step-NN-*.{png,json,txt}`. New MSCs:

- **MSC-Dash-Render** — Dashboard window renders w/ state pill + hostname + buttons (osascript verifiable)
- **MSC-Dash-Auto** — Dashboard auto-opens post-wizard (osascript window enumeration)
- **MSC-Dash-CopyButton** — Click Copy-SSH + pbpaste matches expected (clipboard verifiable)
- **MSC-Dash-InlineEdit** — Inline subdomain edit triggers CloudflareClient.updateCNAME + state restart (CF API call observable)
- **MSC-Dash-LogTail** — Live cloudflared lines appear in dashboard scroll (osascript scroll content)
- **MSC-Dash-Metrics** — Connection count + bytes from metrics endpoint visible (osascript dump)
- **MSC-Dash-StopButton** — Click Stop → state flips IDLE + cloudflared exits (pgrep + osascript)
- **MSC-Dash-Notify** — Notification fires on state change (`notifyutil` cross-check)

These are runtime MSCs with click-driven proof — same standard as BurrowE2E CLI.

## §9 — Risk + tradeoffs

This adds ~1090 LOC + 8 new MSCs + significant doc updates. Concurrent w/ the BurrowE2E CLI sub-agent already in flight, that's two parallel build streams. Race risk on CFTunnelApp.swift (BurrowE2E = no GUI changes; Dashboard = adds Scene + edits MenuBar) — mitigatable by ordering: let BurrowE2E finish first, then Dashboard agent works on a stable base.

Three options:

(a) **Full Dashboard refit (D-A through D-K).** ~1090 LOC, ~2-3h sub-agent runtime. Closes UX gap completely. Highest scope.

(b) **Dashboard skeleton (D-A + D-H + D-I only).** ~290 LOC, ~30min. Hero hostname + state-pill + open-dashboard wiring + auto-launch. Defers metrics/QR/log-tail/notifications/diagnostics. Closes "no dashboard exists" complaint.

(c) **Skip — defend menubar-only design.** Already rejected.

**Recommendation:** (a) full, given user mandate "rethink all different user experiences" + "executed and confirmed end-to-end" + "configure certain things when they open the application." Skeleton (b) doesn't address the "configure" requirement.

## §10 — Awaiting user direction

Before dispatching code worker, want explicit go/no-go on:

1. **Scope** — (a) full Dashboard refit, (b) skeleton, or split into incremental sub-iterations?
2. **Layout** — does §3 ASCII mockup match user's mental model? Anything to add/remove?
3. **First-launch flow** — auto-open Dashboard after wizard per §4? Or menubar-only by default w/ a "Show Dashboard" preference?
4. **MenuBar reorder** — add "Open Dashboard…" at top per §5?
5. **Inline config edits** — subdomain editable directly on Dashboard per §3 (instead of hopping to Settings)?
6. **PRD/PRP/BRAND updates** — author concurrently or post-hoc?
7. **AT-Dashboard E2E** — full 12-step osascript validation per §8?

The BurrowE2E CLI sub-agent already in flight is unaffected by these decisions (no GUI overlap). It can continue while we triage Dashboard scope.

---

**Note on Burrow process hygiene:** zero Burrow.app processes currently running, zero cloudflared processes (verified via `ps -ef | grep -iE "Burrow\.app|cloudflared"`). The 2 processes the user killed are gone — system is clean.
