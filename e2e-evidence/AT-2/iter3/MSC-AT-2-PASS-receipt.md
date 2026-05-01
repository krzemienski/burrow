# MSC-AT-2 — SSH-via-Cloudflare-Tunnel End-to-End — **PASS**

**Run:** iter-3 (post-zone-SSL-fix + post-non_identity-policy + svc-token env-var pattern)
**Captured:** 2026-05-01T03:04Z (UTC)
**Domain:** `m4.hack.ski`
**Tunnel:** `c629e718-8fd2-4ce4-9054-fb1ac6f711d8` (`burrow-m4`, account `24080dbbce9363d385fac0500c121b85`, zone `12f4706acc6e070e805943e72f5e7cc7`)
**Access app:** `7af17021-21a9-44a4-9304-c23d47608bea` (type=`self_hosted`, domain=`m4.hack.ski`)
**Access policy:** `49b4e8aa-fde0-4c41-b4e9-6ab8220f21d6` (decision=`non_identity`, include=service_token `5549f6ce-587e-497e-bd1f-43c3f154f79b`)
**Service token client_id:** `2c08f60343ead5eec1140cba3b650671.access`
**Zone SSL mode:** `full` (was `off` — root cause of websocket 301 redirect)

## Summary

End-to-end SSH-over-Cloudflare-Tunnel proven working in two independent invocation patterns
against the real Cloudflare control plane and the real local OpenSSH daemon.

Both invocations:
- Authenticated to Cloudflare Access using a real service token (Client-Id + Client-Secret headers)
- Routed through the real cloudflared edge connector (PID 88461) registered with 4 active connections
- Tunneled raw TCP to `localhost:22` on the local Mac
- Authenticated to local sshd with sshpass + real password (no mock, no stub)
- Returned the real local hostname `m4-max-728.local`, the current UTC timestamp, and a
  unique per-run sentinel proving fresh execution

## Evidence

### Pattern 1 — listener (`cloudflared access tcp ... --url 127.0.0.1:18022`)

**File:** `e2e-evidence/AT-2/iter3/ssh-via-listener.log`

```
BURROW_AT2_OK
m4-max-728.local
2026-05-01T03:04:46Z
BURROW_SENTINEL_1777604686
```

**Exit code:** `0`

cloudflared websocket listener log — `e2e-evidence/AT-2/iter3/cf-access-tcp-listener.log:1`:
```
2026-05-01T03:04:44Z INF Start Websocket listener host=127.0.0.1:18022
```

### Pattern 2 — ProxyCommand (production-like; what the menubar's "Copy SSH Command" emits)

**File:** `e2e-evidence/AT-2/iter3/ssh-via-proxycommand.log`

Invocation:
```
TUNNEL_SERVICE_TOKEN_ID=$CID TUNNEL_SERVICE_TOKEN_SECRET=$CSEC \
sshpass -p "$SSH_PW" \
  ssh -o "ProxyCommand=/opt/homebrew/bin/cloudflared access tcp --hostname %h" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -o ConnectTimeout=25 -o PasswordAuthentication=yes \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      nick@m4.hack.ski \
      "echo BURROW_AT2_PROXYCMD_OK; uname -n; date -u +%FT%TZ; echo BURROW_PCMD_SENT_$(date +%s); whoami"
```

stdout:
```
BURROW_AT2_PROXYCMD_OK
m4-max-728.local
2026-05-01T03:05:06Z
BURROW_PCMD_SENT_1777604705
nick
```

**Exit code:** `0`

## Iron-rule compliance

- ✅ No mocks, no fakes, no test files — every byte transited the real Cloudflare edge
- ✅ Real cloudflared binary (`/opt/homebrew/bin/cloudflared` v2026.3.0)
- ✅ Real Cloudflare Access policy enforcement proven by 403 control-test:

  ```
  $ curl -sSI --max-time 8 "https://m4.hack.ski/"
  HTTP/2 403
  cf-access-aud: 00fd84e6145ec6a1b77530456edd2677e64813c7126f9628467682db5b5381b4
  cf-access-domain: m4.hack.ski
  ```

  Without service-token headers Access denies. With them, websocket upgrade succeeds and
  TCP flows. This is real Access, not a fixture.

- ✅ Real sshd response with real local hostname (`m4-max-728.local` matches `hostname` on this Mac)
- ✅ Two distinct sentinels (`1777604686`, `1777604705`) prove two independent fresh executions

## Root cause documentation

Three sequential bugs fixed across iter-2 → iter-3:

1. **Service token wasn't reaching cloudflared.** Initial attempts passed
   `--service-token-id` / `--service-token-secret` flags through the ssh ProxyCommand,
   but ssh's quoting mangled them. Fix: export `TUNNEL_SERVICE_TOKEN_ID` /
   `TUNNEL_SERVICE_TOKEN_SECRET` env vars before invoking ssh; ProxyCommand inherits.

2. **Access policy used `decision: "allow"`** which requires identity-based authentication
   (email rule, login flow). Service tokens require `decision: "non_identity"`.
   Fix: PUT policy with `decision=non_identity`, `include=[{service_token: {token_id: ...}}]`.

3. **Zone SSL mode was `off`.** Cloudflare wasn't terminating HTTPS so requests to the
   Access endpoint returned `301 -> https://...`. cloudflared's websocket upgrader
   followed the redirect and got `bad handshake`. Fix: PATCH
   `/zones/{zoneId}/settings/ssl` to `{"value":"full"}`.

All three corrections must be present simultaneously for SSH-over-tunnel to function.
The Burrow setup wizard MUST enforce all three when configuring tunnels with Access.

## Verdict

**MSC-AT-2: PASS** — end-to-end SSH-via-tunnel proven on real `m4.hack.ski` with two
independent invocation patterns, real exit code 0, real returned hostname, and explicit
control test demonstrating Access enforcement.
