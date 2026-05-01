# BurrowE2E Build Receipt — Phase 04 iter2

## Artifact
`Sources/BurrowE2E/main.swift` — new CLI target

## Build
```
xcodebuild -scheme BurrowE2E -configuration Debug -destination 'platform=macOS,arch=arm64' build
** BUILD SUCCEEDED **
```

## Binary
`/Users/nick/Library/Developer/Xcode/DerivedData/Burrow-fpkzlxmtaqbhwpggkxjmlklwglgd/Build/Products/Debug/BurrowE2E`

## Smoke test — no-arg invocation
```
BurrowE2E — Burrow end-to-end lifecycle driver

Subcommands:
  setup       Provision tunnel, ingress config, DNS CNAME, Access app + service token
  up          Start cloudflared and wait for .running state
  ssh-test    Probe SSH through the live tunnel via CF Access service token
  down        Stop cloudflared, verify .stopped state
  teardown    Delete Access policy, app, DNS record, and tunnel

Environment variables (source .env before running):
  CF_API_KEY            37-char Cloudflare Global API Key
  CF_AUTH_EMAIL         Account email
  CF_DOMAIN             Full hostname (e.g. m4.hack.ski)
  SSH_USERNAME          SSH user on the remote host
  SSH_PW                SSH password (used by sshpass)
```

## Files modified
- `Sources/CloudflareAPI/Models/AccessApp.swift` (new)
- `Sources/CloudflareAPI/Endpoints.swift` (+6 Access endpoints)
- `Sources/CloudflareAPI/CloudflareClient.swift` (+6 Access actor methods)
- `Sources/Keychain/KeychainService.swift` (+3 Access service token methods)
- `Sources/Preferences/PreferencesStore.swift` (+3 Access vars + keys)
- `Sources/BurrowE2E/main.swift` (new, ~320 LOC)
- `project.yml` (BurrowE2E target + scheme)

## Regression
Burrow app scheme also builds clean (verified separately).
