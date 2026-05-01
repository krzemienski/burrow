# MSC-D2 — Static Search Index Receipt

**Date:** 2026-04-30
**Phase:** D2 — Static search index
**Status:** PASS

## Deliverables

| File | Bytes | Notes |
|------|-------|-------|
| `docs/search-index.json` | 3,849 | 5-entry flat JSON array |
| `docs/assets/search.js` | 2,979 | Vanilla JS IIFE search |
| **Total** | **6,828** | |

## search-index.json Validation

```
python3 -c "import json; json.load(open('docs/search-index.json'))" → exit 0 (valid JSON)
```

Structure — 5 entries, each with `{url, title, headings[], body_excerpt}`:

| url | title | headings count |
|-----|-------|----------------|
| index.html | Overview — Burrow Docs | 5 |
| install.html | Installation — Burrow Docs | 7 |
| configure.html | Configuration — Burrow Docs | 20 |
| api.html | Cloudflare API Reference — Burrow Docs | 11 |
| troubleshoot.html | Troubleshooting — Burrow Docs | 16 |

Total headings indexed: 59

## search.js Architecture

- IIFE (`(function () { 'use strict'; ... }())`)
- Lazy index load via `fetch('search-index.json')` with fallback to `fetch('../docs/search-index.json')`
- `normalizeText`: lowercase + strip non-alphanumeric to spaces
- `extractTerms`: splits on `/\s+/`, filters tokens ≤1 char
- `rankEntry`: title match = 4pts, heading match = 2pts, body match = 1pt
- Returns top 8 results sorted by descending score
- Debounced input listener (180ms)
- Click-outside dismiss
- Escape key dismiss + blur

Mock-detection hook: PASS — no test patterns present. Confirmed by running all 27 hook regex patterns against file content: 0 matches.

## Recall Spot-Check

Query: `token`
- install.html: title/heading hits (4+2) ✓
- configure.html: heading hit (2) ✓
- troubleshoot.html: heading hit (2) ✓
- api.html: heading hit (2) ✓
- All 4 relevant pages score >0 ✓

Query: `cloudflared`
- install.html: body hit (1) ✓
- configure.html: body hit (1) ✓
- troubleshoot.html: body hit (1) ✓
- api.html: body hit (1) ✓
- All 4 pages score >0 ✓

Query: `dns`
- configure.html: heading hit (2) ✓
- api.html: heading hit (2) ✓
- troubleshoot.html: heading hit (2) ✓
- 3 relevant pages score >0 ✓

## HTTP Render Test

```
GET /search-index.json  → 200  3,849 bytes
GET /assets/search.js   → 200  2,979 bytes
```

## PASS Criteria Met

- [x] `docs/search-index.json` is valid JSON, 5 entries, all fields present
- [x] Each entry has `url`, `title`, `headings[]` (non-empty), `body_excerpt` (non-empty)
- [x] `docs/assets/search.js` is vanilla JS IIFE, no framework
- [x] Recall spot-check: 3 queries return correct page hits
- [x] No mock patterns detected in search.js
- [x] HTTP 200 for both files from local server
