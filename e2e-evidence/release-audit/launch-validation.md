# Burrow Launch Validation — release-audit

**Run:** 2026-05-01 (forge full audit)
**Build:** Release, ad-hoc signed (CODE_SIGN_IDENTITY="-")
**Bundle:** com.krzemienski.burrow v1.0.0 (build 1)
**Binary arch:** Universal (x86_64 + arm64)
**Binary size:** 6,507,544 bytes (6.2 MB)
**App size:** 6,509,282 bytes total
**Launched as PID:** 89548
**RSS at launch:** 97,136 KB (~95 MB cold; PRD §G5 target <50 MB after 24h soak)

## Bundle structure
```
Burrow.app/
└── Contents/
    ├── Info.plist        (1730 B; LSUIElement=true, bundle id correct)
    ├── PkgInfo           (8 B)
    └── MacOS/
        └── Burrow        (6,507,544 B, universal)
```

## Info.plist verified keys
- CFBundleIdentifier: com.krzemienski.burrow ✓
- CFBundleShortVersionString: 1.0.0 ✓
- LSMinimumSystemVersion: 14.0 ✓
- LSUIElement: true ✓ (no Dock icon)
- LSApplicationCategoryType: public.app-category.developer-tools ✓
- NSAppTransportSecurity.NSAllowsArbitraryLoads: false ✓

## Launch evidence
- `open` exit 0
- `pgrep -lf Burrow.app/Contents/MacOS/Burrow` → 89548 (running)
- `osascript "tell System Events to count menu bar items of menu bar 1 of (first application process whose name is \"Burrow\")"` → **6** (menu bar icon present)
- `osascript "tell System Events ... exists process \"Burrow\""` → **true**
- Screenshot: `menubar-burrow-running.png` (1.4 MB)

## Auto-start (SMAppService) wiring
- `Sources/UI/Settings/GeneralTab.swift:86` calls `SMAppService.mainApp.register()` on toggle ON
- `Sources/Preferences/PreferencesStore.swift:73` persists `launchAtLogin` UserDefaults key
- `Sources/UI/Settings/GeneralTab.swift:78` reads `SMAppService.mainApp.status` on appear and exposes "Open Login Items" button when `.requiresApproval`
- Verified in source; user-facing path: Settings → General → "Launch at login" toggle

## Known cosmetic gaps (non-blocking)
- `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares 10 PNGs but PNG files absent — does not affect menu-bar app (LSUIElement=true hides Dock icon)
- `MenuBarIcon.imageset/Contents.json` empty placeholder — `CFTunnelApp.swift` uses `Image(systemName: "network.slash")` SF Symbol fallback, menu icon renders correctly
- `AccentColor.colorset/Contents.json` correctly declares `#FF6A1A` light + lifted dark variant ✓

## Verdict
PASS — Burrow.app builds, launches, registers menu-bar icon, presents process, and SMAppService auto-start path is wired in source. Cosmetic asset PNGs missing; ship-blocker only if Dock icon mode is later enabled.
