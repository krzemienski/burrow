# MSC-4c — CloudflaredManager.start() Runtime — **PASS**

**Run:** iter-3
**Captured:** 2026-05-01T03:18Z (UTC)
**Tunnel:** `c629e718-8fd2-4ce4-9054-fb1ac6f711d8` (`burrow-m4`, m4.hack.ski)

## Claim

`Sources/TunnelCore/CloudflaredManager.swift` actor exposes `start(runToken:)` which spawns the real `cloudflared` binary as a child Process, monitors its stderr for the connection-registration line, and transitions internal state from `.idle` → `.starting` → `.running`. This MSC requires real-system runtime evidence that the actor reaches `.running` against the live Cloudflare control plane.

## Evidence

**File:** `e2e-evidence/phase-04/iter3/burrowe2e-up.log`

```
[01] getRunToken tunnelID=c629e718-8fd2-4ce4-9054-fb1ac6f711d8
[01] ok token_len=240
[02] manager.start()
[02] polling for .running (30s budget)
[STATE] starting
[STATE] running
[EVIDENCE] wrote /Users/nick/Desktop/cf-tunnel-menubar/e2e-evidence/AT-2/up.json (79 bytes)
[UP_OK] {
  "tunnel_id": "c629e718-8fd2-4ce4-9054-fb1ac6f711d8",
  "state": "running"
}
[UP_OK] detach — pid_file=/Users/nick/Desktop/cf-tunnel-menubar/e2e-evidence/AT-2/cloudflared.pid
exit=0
```

**Companion artifact:** `e2e-evidence/AT-2/up.json`

```json
{
  "tunnel_id": "c629e718-8fd2-4ce4-9054-fb1ac6f711d8",
  "state": "running"
}
```

## What this proves

1. **Real KeychainService → Plist read.** Step `[01] getRunToken` invoked `KeychainService.shared.getRunToken(tunnelID:)` which delegated to PrefsTokenStore (UserDefaults plist). Returned a 240-char Cloudflare run token from prior `setup`. No Keychain prompts, no interactive auth.

2. **Real CloudflaredManager actor invocation.** Step `[02] manager.start()` invoked `CloudflaredManager.shared.start(runToken:)` — the production actor under test, not a mock or shim.

3. **Real state machine transitions.** Two distinct `[STATE]` log lines emitted by the polling loop reading `await manager.state`:
   - `[STATE] starting` — actor entered the .starting state after spawning the cloudflared child Process
   - `[STATE] running` — actor transitioned to .running after observing the connection-registration line in cloudflared's stderr

4. **Real Cloudflare edge handshake.** The actor only reaches `.running` after parsing cloudflared's `Registered tunnel connection` stderr line. cloudflared cannot emit that line without a successful TLS handshake against the Cloudflare control plane and a successful tunnel registration.

5. **Real exit 0.** The polling loop did not time out (30s budget); BurrowE2E exited cleanly.

## Iron-rule compliance

- ✅ No mocks, no fakes, no test files — real CloudflaredManager actor against real cloudflared binary against real Cloudflare control plane
- ✅ No XCTest, no test framework — direct CLI invocation captured to log
- ✅ Real Process subprocess (no `Process()` wrapper in production code outside CloudflaredManager — verified by Reviewer C scan)
- ✅ Token scrubbed from log per CLAUDE.md §7

## Verdict

**MSC-4c: PASS** — CloudflaredManager.start() runtime exercise proven via Swift BurrowE2E driver against real Cloudflare control plane. Actor transitioned `.idle → .starting → .running` within budget.

## Cross-reference

- iter-2 already proved cloudflared CAN reach connector state via shell invocation (`e2e-evidence/phase-04/iter2/cloudflared-stderr.log:13-19` — 4 "Registered tunnel connection" lines from datacenters ewr01/05/07/16). This iter-3 receipt closes the gap by proving Burrow's actor specifically performs that orchestration.
