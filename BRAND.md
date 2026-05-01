# Burrow — Brand Lock

**Locked:** 2026-04-30
**Visual reference:** `~/.agent/diagrams/burrow-brand-kit.html`

---

## 1. Name

**Burrow** — single word, lowercase in all UI surfaces, sentence-case only in legal / marketing copy.

- App name: `Burrow`
- Bundle ID: `com.krzemienski.burrow`
- Tunnel naming convention: `burrow-<hostname>`
- OSLog subsystem: `com.krzemienski.burrow`

Tagline: **"Your machine, teleported."**

## 2. Logotype

- Wordmark font: **Space Grotesk**, weight 700, letter-spacing −1.5px, lowercase.
- Mark: half-circle arch over a horizon line — the abstract "burrow opening".
- Pulse dot inside the arch = live tunnel.
- All marks render flat — no gradients, no soft shadows. Hard edges, neon glow only.

Min sizes:
- Mark alone: 16×16 px
- Wordmark + mark lockup: 96×24 px

## 3. Color tokens

### Primary palette — Hybrid Black Bean

| Token | Hex | Use |
|------|-----|-----|
| `--bean-0` | `#050302` | Outer void / page background lowest |
| `--bean-1` | `#0E0907` | Page background |
| `--bean-2` | `#170F0B` | Surface |
| `--bean-3` | `#221610` | Elevated surface |
| `--bean-4` | `#2E1F16` | Recessed |
| `--bean-5` | `#4A3526` | Divider |
| `--bean-6` | `#6E5A48` | Dim text |
| `--cream`   | `#F5E9D7` | Primary text |
| `--cream-2` | `#C9B7A1` | Secondary text |

### Accent — Cyber Orange

| Token | Hex | Use |
|------|-----|-----|
| `--orange`      | `#FF6A1A` | Primary accent — buttons, active state, menu icon when running |
| `--orange-hot`  | `#FF8838` | Hover, active interaction |
| `--orange-deep` | `#E54A00` | Press, deep accent border |
| `--orange-glow` | `#FFB85A` | Highlight, pulse, success flash |

### Cyberpunk supports (sparingly)

| Token | Hex | Use |
|------|-----|-----|
| `--magenta` | `#FF1F6D` | Alarm, auth failure, token revoked |
| `--acid`    | `#C8FF1A` | Success state pip on running tunnel |
| `--ice`     | `#18E0FF` | Link hover only — never used as primary |

**Forbidden:** any indigo / violet (`#8b5cf6`, `#7c3aed`), any pastel, any soft gradient, any glassmorphism. Cyber-orange on black-bean = the entire brand.

## 4. Typography

| Role | Font | Size | Tracking |
|------|------|------|----------|
| Display | Space Grotesk 700 | 64 px | −2.5 |
| Headline | Space Grotesk 600 | 32 px | −0.8 |
| Title | Space Grotesk 600 | 20 px | −0.3 |
| Body | Space Grotesk 400 | 15 px | 0 |
| Mono lg | JetBrains Mono 500 | 14 px | 0.5 |
| Mono | JetBrains Mono 400 | 11 px | 0.5 |
| Label | JetBrains Mono 600 | 10 px | 2.0 caps |

In-app: SF Pro (system default) acceptable substitute when web fonts not loadable. Never Inter, never Roboto.

## 5. Iconography

- Menu bar icon = mark only (16×16, monochrome template image, tinted by `--orange` when running).
- App icon = mark on `--bean-0` rounded square with `border: 2px solid var(--orange)` equivalent in raster terms, faint scanline overlay.
- All UI icons: SF Symbols only, never custom raster.

## 6. Voice & tone

### Say this

- "tunnel up." 4h 12m.
- "missing scope: zone:dns:edit" with copy button.
- "install with brew install cloudflared" — verbatim.
- "token revoked" with one-click re-enter.
- "reconnecting in 4s" with attempt counter.

### Never this

- "successfully established secure connection!"
- "oops! something went wrong."
- "lightning fast" / "blazingly secure" / "enterprise grade"
- emoji in error states (🚀, 🎉, ⚡, ❌)
- marketing voice in the menu — show the SSH command instead.

### 6.1 Dashboard copy (D-Refit, 2026-04-30)

Sample copy that the Dashboard surfaces verbatim — keep it terse, factual, and operative. No marketing voice; no exclamation marks.

1. Hero state pill: `RUNNING` · `4h 12m up`
2. Hero hostname row: `m4.hack.ski` (28pt, cream) with `[edit]` affordance and `ssh nick@m4.hack.ski` block
3. QR caption: `scan to ssh`
4. Recent-activity placeholder when buffer is empty: `— waiting for tunnel logs —`
5. Network status: `online · home-2.4G · Local SSH on :22 ✓`
6. Diagnostics verdict: `PASS — tunnel reachable from internet (HTTP 401, 142ms)`

## 7. Motion rules

| Motion | Timing | Use |
|--------|--------|-----|
| State changes | 160 ms · `steps(2)` | Hard cut between running / connecting / stopped / failed |
| Connecting pulse | 1.0 s · `steps(2)` infinite | Two-frame opacity blink during reconnect |
| Running glow | static | Running state never animates — it's just on |
| Success flash | 240 ms · ease-out | First-connection acid-green halo, one-shot |
| Failure shake | 320 ms · 3 cycles | Menu icon shifts ±2 px on auth failure |
| Reduced motion | 0.01 ms | Respect `prefers-reduced-motion` — collapse all to instant |

## 8. Cloudflare API token — required scopes

These four are the only scopes Burrow asks for. Show them verbatim in the wizard and Settings → Cloudflare tab:

```
Account → Cloudflare Tunnel → Edit
Zone    → DNS               → Edit
Zone    → Zone              → Read
Account → Account Settings  → Read
```

## 9. Asset export checklist (Phase 9 deliverable)

- [ ] `brand/logo-mark.svg` (primary + inverse)
- [ ] `brand/logo-wordmark.svg`
- [ ] `brand/app-icon-1024.png` (with raster scanline)
- [ ] `brand/app-icon-512@2x.png`, 256, 128, 64, 32, 16
- [ ] `brand/menubar-icon-template.svg` (monochrome, macOS template image)
- [ ] `brand/social-card-1200x630.png` (for README + future site)
- [ ] `Resources/Assets.xcassets/AppIcon.appiconset/` populated
- [ ] `Resources/Assets.xcassets/AccentColor.colorset/` set to `#FF6A1A`
- [ ] `Resources/Assets.xcassets/MenuBarIcon.imageset/` template variants

---

**Brand authority:** This file. If it's not in this file, it's not in the brand. PR's that introduce new colors, fonts, or motion patterns must update this doc first.
