# MSC-S1-source — Marketing Site Scaffold Receipt

**Date:** 2026-04-30
**Phase:** S1 — Marketing site scaffold
**Status:** PASS

## Deliverables

| File | Bytes | Notes |
|------|-------|-------|
| `site/index.html` | 18,693 | Single-page marketing HTML5 |
| `site/assets/main.css` | 13,628 | Brand tokens + full layout CSS |
| `site/assets/burrow.svg` | 633 | 48×48 logo mark (orange arch, acid dot) |
| `site/assets/wordmark.svg` | 597 | 200×40 wordmark SVG |
| **Total** | **33,551** | |

## Content Validation

`site/index.html` contains:
- Hero section with product headline and CTA
- "How it works" section (4-step numbered flow: token → wizard → cloudflared → SSH)
- Features section (6 cards: no port forwarding, keychain secrets, auto-reconnect, launch-at-login, menu bar, notarized)
- Requirements section (macOS 13, cloudflared, Cloudflare account)
- Download CTA

Brand compliance:
- Background: `#050302` (bean-0)
- Accent: `#FF6A1A` (orange)
- Pulse indicator: `#C8FF1A` (acid)
- Fonts: Space Grotesk + JetBrains Mono via Google Fonts @import
- No framework — vanilla HTML/CSS/JS only

## SVG Validation

```
xmllint --noout site/assets/burrow.svg    → exit 0
xmllint --noout site/assets/wordmark.svg  → exit 0
```

## HTTP Render Test

Server: `python3 -m http.server 8771` from `site/`

```
GET /index.html          → 200  18,693 bytes
GET /assets/main.css     → 200  13,628 bytes
GET /assets/burrow.svg   → 200     633 bytes
GET /assets/wordmark.svg → 200     597 bytes
```

All responses confirmed non-empty with correct Content-Type headers.

## PASS Criteria Met

- [x] `site/index.html` exists, >200 words of real product content
- [x] `site/assets/main.css` exists with brand tokens as CSS custom properties
- [x] `site/assets/burrow.svg` — valid SVG, xmllint exit 0
- [x] `site/assets/wordmark.svg` — valid SVG, xmllint exit 0
- [x] No framework dependencies — pure HTML/CSS/JS
- [x] HTTP 200 for all four files from local server
