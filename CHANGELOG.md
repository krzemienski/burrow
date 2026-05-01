# Changelog

All notable changes to **Burrow** are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc1] — 2026-05-01

First release candidate. Source tree builds, app launches, menu-bar icon
renders, first-run wizard displays. Capability-gapped acceptance tests
deferred to user-driven final pass (see `GAP-ANALYSIS.md`).

### Added
- Native `MenuBarExtra` menu-bar app (`LSUIElement=true`, no Dock icon)
- `CloudflareClient` actor wrapping a single `URLSession`, 11 typed CF API v4 endpoints (`/user/tokens/verify`, `/accounts`, `/zones`, `/accounts/:id/cfd_tunnel` × 4, `/zones/:id/dns_records` × 3, `/accounts/:id/access/apps`)
- `CloudflaredManager` actor owning the child `cloudflared` `Process` with `SIGTERM` → `SIGKILL` shutdown ladder
- 7-step first-run wizard (Welcome, Token, Account/Zone, Subdomain, cloudflared check, Create Tunnel, Done)
- 5-tab Settings (General, Cloudflare, Tunnel, DNS, Advanced)
- Live Dashboard window with tunnel state observer
- `KeychainService` (Security framework `SecItem*`) for API token + tunnel run token
- `PreferencesStore` UserDefaults bridge for non-secret prefs
- `NWPathMonitor` + `PowerObserver` for network/sleep recovery
- `Notifier` (`UNUserNotificationCenter`) with action buttons
- `SMAppService` "Launch at login" wired in General tab with `requiresApproval` UI fallback
- `OSLog` subsystem `com.krzemienski.burrow` with categories `tunnel`, `cloudflare`, `network`, `ui`, `keychain`, `lifecycle`
- Marketing site source (`site/index.html`)
- Docs site source (5 pages: index, install, configure, api, troubleshoot) + Lunr-style search index
- Brand kit: logo SVGs, menu-bar icon template, design tokens (`brand/tokens.css`)
- Real-system validation evidence under `e2e-evidence/` for phases 0–4 + AT-2 + AT-Dashboard

### Changed
- `AccentColor.colorset` declares cyber-orange `#FF6A1A` light + lifted dark variant

### Security
- API token + tunnel run token live exclusively in Keychain (no UserDefaults, no plist, no OSLog leakage)
- All tunnels created with `config_src: "cloudflare"` (cloud-managed)
- Ingress arrays terminate with `{ "service": "http_status:404" }`
- `cfargotunnel.com` CNAMEs use `proxied: true`
- `--token \S+` scrubbing on captured cloudflared command lines before OSLog emission
- DNS API responses' `result` body stripped on error paths
- `NSAllowsArbitraryLoads=false` in Info.plist

### Known issues
- Universal binary is **ad-hoc signed** only; Developer ID signing + notarization deferred to v1.0.0 final (capability gap — see `GAP-ANALYSIS.md` §4)
- AppIcon PNGs not yet exported (cosmetic; menu-bar app does not show a Dock icon)
- 4 docs pages outstanding (architecture, security, release-notes, support)
- Marketing + docs sites not yet deployed to `burrow.hack.ski`
- Cold-launch RSS observed at ~95 MB; PRD §G5 target is < 50 MB after 24 h soak — unverified in this session

[1.0.0-rc1]: https://github.com/krzemienski/burrow/releases/tag/v1.0.0-rc1
