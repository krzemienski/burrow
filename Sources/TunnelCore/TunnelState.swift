// TunnelState.swift
// Burrow — tunnel lifecycle state machine.

import Foundation

/// Single source of truth for what the tunnel is doing right now.
/// Mutated only by `CloudflaredManager`. Read by `MenuBarContentView`
/// and `SettingsView` via an @Observable wrapper (added in Phase 4).
enum TunnelState: Equatable {

    case idle

    /// We've issued `Process.run()` but haven't seen the
    /// "Registered tunnel connection" line on stderr yet.
    case starting

    /// Connection established. Holds the metadata we display in the menu bar.
    case running(tunnelID: String, hostname: String, since: Date)

    /// Lost connection; backoff timer running between attempts.
    case reconnecting(attempt: Int)

    /// Terminal error that the user must act on (auth failure, missing binary,
    /// API error). UI surfaces a notification + Settings highlight.
    case failed(reason: String)

    /// User-initiated stop. The state machine will not auto-recover.
    case stopped

    var isOperational: Bool {
        switch self {
        case .running: return true
        default: return false
        }
    }

    var displayLabel: String {
        switch self {
        case .idle:                       return "idle"
        case .starting:                   return "starting"
        case .running:                    return "running"
        case .reconnecting(let attempt):  return "reconnecting · attempt \(attempt)"
        case .failed(let reason):         return "failed — \(reason)"
        case .stopped:                    return "stopped"
        }
    }
}
