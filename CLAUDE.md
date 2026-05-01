# CLAUDE.md — Burrow project rules

Project-specific guidance for Claude Code (and any other autonomous agent) operating in this repo. Layer this on top of the global `~/.claude/CLAUDE.md`.

## 0. Identity

The product name is **Burrow**. Use it in user-facing strings, log messages, error copy, README, and the Xcode project name. Use `cf-tunnel-menubar` only as the directory codename.

Bundle ID: `com.krzemienski.burrow`
OSLog subsystem: `com.krzemienski.burrow`

## 1. Source-of-truth documents

Read these in order before any non-trivial change:

1. `PRD.md` — what the product is and why
2. `PRP.md` — exactly how to build it (endpoint shapes, gotchas, phases, pseudocode)
3. `BRAND.md` — visual identity, colors, fonts, voice
4. `PHASES.md` — current execution status

If your change conflicts with any of these, update the doc first or stop and ask.

## 2. Iron rules (from PRP §6)

- **No mocks, no fixtures, no test files.** No `XCTest` target. No `Mock*` classes. No `Fake*` classes.
- **Every Cloudflare API call hits real `api.cloudflare.com`.** No simulated responses.
- **Every `cloudflared` invocation uses the real binary** against the real Cloudflare control plane.
- **Compilation is not validation.** A green build is necessary but not sufficient. Phase N is complete only when its evidence artifact is captured under `e2e-evidence/phase-NN/` and is non-empty.
- **Empty files (0 bytes) are invalid evidence.**
- **Cite evidence on every claim.** Saying "phase N is done" without citing a file path is invalid.

## 3. Architectural constraints

- **One** `CloudflareClient` actor wraps **one** `URLSession`. No second HTTP client appears anywhere.
- **One** `CloudflaredManager` actor owns the child `Process`. No bare `Process()` outside this actor.
- **API token** lives only in Keychain. Tunnel run token lives only in Keychain. Nowhere else — not in UserDefaults, not in plist, not in OSLog.
- **All tunnels created with** `config_src: "cloudflare"` (cloud-managed). Never `local`.
- **All ingress arrays end with** `{ "service": "http_status:404" }`.
- **All `cfargotunnel.com` CNAMEs** use `proxied: true`.
- **`LSUIElement = YES`** — no Dock icon.
- **Hardened Runtime ON, App Sandbox OFF** for v1.0. Refactor to sandboxed in v1.2 (see PRD §13 Q1).
- **Native APIs only:** `MenuBarExtra`, `SMAppService`, `NWPathMonitor`, `Process`, `OSLog`, `UNUserNotificationCenter`. No deprecated alternatives (`NSStatusItem`, `SMLoginItemSetEnabled`, `SCNetworkReachability`, `print`, `swift-log`).

## 4. Files you should never write

- `Tests/`, `*.test.swift`, `*Tests.swift`, `*Mock*.swift`, `*Fake*.swift`
- `Package.resolved` outside SPM-managed contexts
- Anything inside `e2e-evidence/` from a Swift source file (evidence is captured manually with screenshots / `log show` / `curl`)

## 5. Files you should always update together

- Adding a new Cloudflare endpoint → update `Sources/CloudflareAPI/Endpoints.swift` + a new model in `Models/` + the gotcha row in `PRP.md` if you discover one.
- Adding a new tunnel state → `Sources/TunnelCore/TunnelState.swift` + the state machine in `CloudflaredManager.swift` + the menu-bar icon switch in `MenuBarContentView.swift`.
- Adding a new preference → `Sources/Preferences/PreferencesStore.swift` + a settings tab in `Sources/UI/Settings/`.

## 6. Phase discipline

You may not jump to Phase N if Phase N-1 has no evidence artifact. Always check `PHASES.md` first. If a phase is marked ⬜ and the prior phase is ✅, you may begin. Update `PHASES.md` to 🟧 when starting and ✅ when the artifact is captured.

## 7. Logging hygiene

- Subsystem: `com.krzemienski.burrow`
- Categories: `tunnel`, `cloudflare`, `network`, `ui`, `keychain`, `lifecycle`
- **Scrub `--token \S+` from any captured command line** before it reaches OSLog.
- **Never log full DNS API responses.** Strip `result` body in error paths.
- Use `privacy: .public` only for non-sensitive identifiers (tunnel ID, hostname, state name).

## 8. Brand discipline

If you write a new SwiftUI view:

- Background: `.bean-1` (`#0E0907`) — never pure white, never gray.
- Accent: `Color("AccentColor")` (resolves to `#FF6A1A`).
- Body font: SF Pro (system). For custom typography, only Space Grotesk + JetBrains Mono.
- Never introduce new colors. If you need one, update `BRAND.md` first and add it to `Assets.xcassets`.
- Hard cuts only — no `withAnimation(.easeInOut)` on state changes. Use `withAnimation(.linear(duration: 0.16))` if animation is required at all.

## 9. When you're blocked

Write to `.agent/state/blocked.md` with:

- What you tried (specific commands, file paths, line numbers)
- The exact error or evidence of failure
- The next probe you would run

Do not silently work around blockers by introducing mocks, stubs, or test scaffolding. Stop and surface the block instead.

---

**End of CLAUDE.md — Burrow project.**
