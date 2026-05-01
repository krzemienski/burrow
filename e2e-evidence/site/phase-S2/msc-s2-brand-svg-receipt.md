# MSC-S2 — Brand SVG Assets Receipt

**Date:** 2026-04-30
**Phase:** S2 — Brand SVG assets
**Status:** PASS

## Deliverables

| File | Bytes | Notes |
|------|-------|-------|
| `brand/logo-mark.svg` | 892 | 64×64 rounded-rect mark |
| `brand/logo-wordmark.svg` | 1,093 | 240×64 mark + "burrow" wordmark |
| `brand/menubar-icon-template.svg` | 1,644 | 22×22 dual-variant menu bar icon |
| **Total** | **3,629** | |

## SVG Validation

```
xmllint --noout brand/logo-mark.svg             → exit 0
xmllint --noout brand/logo-wordmark.svg         → exit 0
xmllint --noout brand/menubar-icon-template.svg → exit 0
```

All three files are well-formed XML.

## Visual Specification

### logo-mark.svg (64×64)
- Background: `rx=12` rounded rect, fill `#0E0907` (bean-1)
- Horizon line: `x1=8 y1=42 x2=56 y2=42`, stroke `#4A3526` (bean-4), width 1.5
- Left stake: `x1=8 y1=42 x2=8 y2=47`
- Right stake: `x1=56 y1=42 x2=56 y2=47`
- Arch: `M14 42 A18 18 0 0 1 50 42`, stroke `#FF6A1A` (orange), width 2.5
- Pulse dot: `cx=32 cy=26 r=3.5`, fill `#C8FF1A` (acid)

### logo-wordmark.svg (240×64)
- Same mark geometry as logo-mark
- Wordmark: "burrow", `x=72 y=44`, Space Grotesk 700, `font-size=28`, `letter-spacing=-1.5`, fill `#F5E9D7` (cream)

### menubar-icon-template.svg (22×22)
- `id="active"` group: horizon + arch in `#FF6A1A`, dot in `#C8FF1A`
  - Horizon: `x1=2 y1=16 x2=20 y2=16`, stroke-width 1.2
  - Arch: `M4 16 A7 7 0 0 1 18 16`, stroke-width 1.5
  - Dot: `cx=11 cy=9.5 r=1.5`
- `id="template-variant"` group: same geometry in black, `display="none"`
- Export targets: 1× (22×22), 2× (44×44), 3× (66×66) for Assets.xcassets

## Brand Compliance

Colors used: `#0E0907` (bean-1), `#4A3526` (bean-4), `#FF6A1A` (orange), `#C8FF1A` (acid), `#F5E9D7` (cream) — all defined in BRAND.md. No new colors introduced.

Font: Space Grotesk 700 (wordmark only) — approved in BRAND.md.

## PASS Criteria Met

- [x] `brand/logo-mark.svg` exists, valid SVG, xmllint exit 0
- [x] `brand/logo-wordmark.svg` exists, valid SVG, xmllint exit 0
- [x] `brand/menubar-icon-template.svg` exists, valid SVG, xmllint exit 0
- [x] All colors match BRAND.md palette — no new colors introduced
- [x] menubar-icon-template has active + template-variant groups for Xcode export
- [x] Export instructions embedded in SVG comments
