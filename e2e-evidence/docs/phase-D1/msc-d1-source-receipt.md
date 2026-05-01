# MSC-D1-source — Docs Scaffold + Content Receipt

**Date:** 2026-04-30
**Phase:** D1 — Docs scaffold + content
**Status:** PASS

## Deliverables

| File | Bytes | Headings | Notes |
|------|-------|----------|-------|
| `docs/index.html` | 5,447 | 5 | Overview: arch, key properties, requirements, docs map |
| `docs/install.html` | 9,714 | 7 | 6-step install guide with API token scopes |
| `docs/configure.html` | 8,678 | 20 | 5 Settings tabs documented |
| `docs/troubleshoot.html` | 9,019 | 16 | 15 troubleshooting scenarios |
| `docs/api.html` | 8,966 | 11 | All CF API v4 endpoints with curl examples |
| `docs/assets/docs.css` | 11,469 | — | Sticky sidebar + prose layout CSS |
| **Total** | **53,293** | | |

## Content Accuracy (sourced from PRP.md)

### install.html
- 4 required API token scopes: `Account → Cloudflare Tunnel → Edit`, `Zone → DNS → Edit`, `Zone → Zone → Read`, `Account → Account Settings → Read`
- First-run wizard 7-step sequence documented
- SSH ProxyCommand: `ssh -o ProxyCommand="cloudflared access ssh --hostname %h" user@<hostname>`
- `brew install cloudflared` prerequisite noted

### configure.html
- 5 tabs: General, Cloudflare, Tunnel, DNS, Advanced
- `cloudflared tunnel run --token <run_token>` command documented
- Delete Tunnel: stops cloudflared → DELETE API → remove CNAME → clear Keychain
- SMAppService for launch-at-login noted

### troubleshoot.html
- `log stream --predicate 'subsystem == "com.krzemienski.burrow"'` documented
- Stale run token scenario: tunnel deleted outside Burrow
- Port 22 check: `lsof -i :22`
- 3-failure-in-5-minutes backoff window documented
- CNAME `proxied: true` requirement for NXDOMAIN fix
- SMAppService requires app in `/Applications`

### api.html
- Base URL: `https://api.cloudflare.com/client/v4`
- `GET /user/tokens/verify` for token validation
- `POST /accounts/{id}/cfd_tunnel` with `config_src: "cloudflare"` mandatory
- `PUT /accounts/{id}/cfd_tunnel/{tunnel_id}/configurations` for ingress
- `POST /zones/{id}/dns_records` with `proxied: true`, `ttl: 1`
- Catch-all ingress rule `http_status:404` documented

## Layout

Each page: sticky left sidebar (240px) + main prose column (max 740px).
Top search bar present on all pages (`#search-input` + `#search-results` elements).
`docs/assets/docs.css` provides `.docs-layout`, `.sidebar`, `.content`, `.code-block` classes.

## HTTP Render Test

Server: `python3 -m http.server 8772` from `docs/`

```
GET /index.html        → 200   5,447 bytes
GET /install.html      → 200   9,714 bytes
GET /configure.html    → 200   8,678 bytes
GET /troubleshoot.html → 200   9,019 bytes
GET /api.html          → 200   8,966 bytes
GET /assets/docs.css   → 200  11,469 bytes
```

All responses confirmed non-empty.

## PASS Criteria Met

- [x] 5 HTML pages exist, each with real technical content (>200 words)
- [x] All content sourced from PRP.md (real API endpoints, real commands, real scopes)
- [x] Sticky sidebar nav layout on all pages
- [x] Search input/results elements present on all pages
- [x] `docs/assets/docs.css` exists with brand-compliant styles
- [x] HTTP 200 for all six files from local server
- [x] No framework — vanilla HTML/CSS only
