# MSC-2a Evidence: CloudflareClient Implementation

**Run ID:** 20260430T231540Z
**Phase:** 5a — Cloudflare API v4 Swift client implementation
**Date:** 2026-04-30

---

## Pre/Post LOC

| File | Before | After |
|------|--------|-------|
| `Sources/CloudflareAPI/CloudflareClient.swift` | 115 LOC | 319 LOC |
| Delta | +204 LOC |

---

## fatalError Count Delta

| State | Count |
|-------|-------|
| Before | 12 (11 endpoint stubs + 1 shared transport) |
| After  | 0 |

Verified with: `grep -n "fatalError" Sources/CloudflareAPI/CloudflareClient.swift | wc -l` → `0`

---

## 11 Implemented Methods

| # | Method | HTTP | Path |
|---|--------|------|------|
| 1 | `verifyToken()` | GET | `/user/tokens/verify` |
| 2 | `listAccounts()` | GET | `/accounts` |
| 3 | `listZones()` | GET | `/zones?per_page=50` |
| 4 | `createTunnel(accountID:name:)` | POST | `/accounts/{aid}/cfd_tunnel` (config_src="cloudflare") |
| 5 | `getTunnelRunToken(accountID:tunnelID:)` | GET | `/accounts/{aid}/cfd_tunnel/{tid}/token` |
| 6 | `setIngressConfig(accountID:tunnelID:hostname:localPort:)` | PUT | `/accounts/{aid}/cfd_tunnel/{tid}/configurations` |
| 7 | `listTunnels(accountID:)` | GET | `/accounts/{aid}/cfd_tunnel?is_deleted=false` |
| 8 | `deleteTunnel(accountID:tunnelID:)` | DELETE | `/accounts/{aid}/cfd_tunnel/{tid}` |
| 9 | `findCNAME(zoneID:name:)` | GET | `/zones/{zid}/dns_records?name=<fqdn>&type=CNAME` |
| 10 | `createCNAME(zoneID:name:target:)` | POST | `/zones/{zid}/dns_records` (proxied=true, ttl=1) |
| 11 | `updateCNAME(zoneID:recordID:name:target:)` | PUT | `/zones/{zid}/dns_records/{id}` |
| 12 | `deleteDNSRecord(zoneID:recordID:)` | DELETE | `/zones/{zid}/dns_records/{id}` |

Note: Method 11 (updateCNAME) and method 12 (deleteDNSRecord) together satisfy PRP §3.3.9 endpoint 11
per the task spec ("PUT ... updateDNSRecord + DELETE ... deleteDNSRecord").

---

## Key Implementation Details

- **Transport:** `execute(_:decode:)` → `performRequest(_:)` → `unwrap(_:type:request:)` pipeline
- **429 backoff:** Single retry after sleeping `Retry-After` header value (default 60s)
- **Error mapping:**
  - 401 → `.invalidToken`
  - 403 + code 9109 → `.insufficientScope(missing:)`
  - 404 → `.notFound`
  - 409 → `.conflict(message:)`
  - 429 (after retry) → `.rateLimited(retryAfter:)`
  - Other non-2xx → `.upstream(status:message:)`
- **Encoding:** `JSONEncoder` with `.convertToSnakeCase`
- **Decoding:** `JSONDecoder` with `.convertFromSnakeCase` into `APIEnvelope<T>`, surfaces `.result`
- **Logging:** OSLog with `.public` privacy on method/path/status; Authorization header never logged
- **ingress catch-all:** `setIngressConfig` always appends `{ "service": "http_status:404" }` as last rule (PRP §3.3.6)

---

## Syntax Check Output

```
swiftc -typecheck CloudflareClient.swift + all 8 dependency files
→ (no output = zero errors, zero warnings)
```

Command:
```
swiftc -typecheck \
  Sources/CloudflareAPI/CloudflareClient.swift \
  Sources/CloudflareAPI/CloudflareError.swift \
  Sources/CloudflareAPI/Endpoints.swift \
  Sources/CloudflareAPI/Models/APIEnvelope.swift \
  Sources/CloudflareAPI/Models/Account.swift \
  Sources/CloudflareAPI/Models/Zone.swift \
  Sources/CloudflareAPI/Models/Tunnel.swift \
  Sources/CloudflareAPI/Models/DNSRecord.swift \
  Sources/CloudflareAPI/Models/TokenVerify.swift
```

Exit code: 0 (clean)

---

## Verdict

PASS — all 11 PRP §3.3 endpoints implemented, 0 fatalError remaining, swiftc type-check clean.
