// BrandTokens.swift
// Burrow — central definition of brand colors per BRAND.md §3.
//
// All Dashboard / settings UI colors must come from this enum. Never use
// raw hex literals or system semantic colors that would conflict with the
// black-bean / cyber-orange identity.

import SwiftUI

enum BrandColor {

    // ── Black Bean palette ────────────────────────────────────────────
    static let bean0     = Color(red: 0x05/255.0, green: 0x03/255.0, blue: 0x02/255.0) // #050302
    static let bean1     = Color(red: 0x0E/255.0, green: 0x09/255.0, blue: 0x07/255.0) // #0E0907 — page background
    static let bean2     = Color(red: 0x17/255.0, green: 0x0F/255.0, blue: 0x0B/255.0) // #170F0B — surface
    static let bean3     = Color(red: 0x22/255.0, green: 0x16/255.0, blue: 0x10/255.0) // #221610 — elevated surface
    static let bean4     = Color(red: 0x2E/255.0, green: 0x1F/255.0, blue: 0x16/255.0) // #2E1F16 — recessed
    static let bean5     = Color(red: 0x4A/255.0, green: 0x35/255.0, blue: 0x26/255.0) // #4A3526 — divider
    static let bean6     = Color(red: 0x6E/255.0, green: 0x5A/255.0, blue: 0x48/255.0) // #6E5A48 — dim text

    // ── Text ──────────────────────────────────────────────────────────
    static let cream     = Color(red: 0xF5/255.0, green: 0xE9/255.0, blue: 0xD7/255.0) // #F5E9D7 — primary text
    static let cream2    = Color(red: 0xC9/255.0, green: 0xB7/255.0, blue: 0xA1/255.0) // #C9B7A1 — secondary text

    // ── Cyber Orange accents ──────────────────────────────────────────
    static let orange      = Color(red: 0xFF/255.0, green: 0x6A/255.0, blue: 0x1A/255.0) // #FF6A1A
    static let orangeHot   = Color(red: 0xFF/255.0, green: 0x88/255.0, blue: 0x38/255.0) // #FF8838
    static let orangeDeep  = Color(red: 0xE5/255.0, green: 0x4A/255.0, blue: 0x00/255.0) // #E54A00
    static let orangeGlow  = Color(red: 0xFF/255.0, green: 0xB8/255.0, blue: 0x5A/255.0) // #FFB85A

    // ── Cyberpunk supports ────────────────────────────────────────────
    static let magenta   = Color(red: 0xFF/255.0, green: 0x1F/255.0, blue: 0x6D/255.0) // #FF1F6D — alarm
    static let acid      = Color(red: 0xC8/255.0, green: 0xFF/255.0, blue: 0x1A/255.0) // #C8FF1A — success
    static let ice       = Color(red: 0x18/255.0, green: 0xE0/255.0, blue: 0xFF/255.0) // #18E0FF — link hover

    /// State-pill background colors per UX-GAP-ANALYSIS §3.
    static func pill(for state: TunnelState) -> Color {
        switch state {
        case .idle, .stopped:       return bean6
        case .starting:             return orangeGlow
        case .running:              return acid
        case .reconnecting:         return orangeHot
        case .failed:               return magenta
        }
    }

    /// State-pill text color (always cream for readability against dark or saturated pills).
    static func pillText(for state: TunnelState) -> Color {
        switch state {
        case .running, .starting:   return bean1   // dark text on bright bg
        case .reconnecting:         return bean1
        default:                    return cream
        }
    }
}

/// Brand typography tokens per BRAND.md §4. SF Pro is the in-app substitute for
/// Space Grotesk per the same spec ("In-app: SF Pro acceptable when web fonts not loadable").
enum BrandFont {
    static let display    = Font.system(size: 64, weight: .bold,     design: .default)
    static let headline   = Font.system(size: 32, weight: .semibold, design: .default)
    static let title      = Font.system(size: 20, weight: .semibold, design: .default)
    static let body       = Font.system(size: 15, weight: .regular,  design: .default)
    static let monoLg     = Font.system(size: 14, weight: .medium,   design: .monospaced)
    static let mono       = Font.system(size: 11, weight: .regular,  design: .monospaced)
    static let label      = Font.system(size: 10, weight: .semibold, design: .monospaced)
}
