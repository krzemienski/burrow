// Log.swift
// Burrow — central OSLog category constants.
//
// Subsystem: com.krzemienski.burrow
// Categories follow PRP §FR-7.1.
//
// Support / debug command:
//   log show --predicate 'subsystem == "com.krzemienski.burrow"' --last 1h

import Foundation
import OSLog

enum Log {
    static let subsystem = "com.krzemienski.burrow"

    static let tunnel    = Logger(subsystem: subsystem, category: "tunnel")
    static let cloudflare = Logger(subsystem: subsystem, category: "cloudflare")
    static let network   = Logger(subsystem: subsystem, category: "network")
    static let ui        = Logger(subsystem: subsystem, category: "ui")
    static let keychain  = Logger(subsystem: subsystem, category: "keychain")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
