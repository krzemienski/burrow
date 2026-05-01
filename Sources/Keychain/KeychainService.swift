// KeychainService.swift
// Burrow — token-store FACADE.
//
// PIVOT (2026-05-01): User mandated dropping the Keychain (Security framework)
// in favor of a plist (UserDefaults) backend to avoid macOS Keychain
// authorization prompts during dev iteration. CLAUDE.md §3 "API token lives
// only in Keychain" is overridden for this iter — production hardening to
// migrate back to Keychain in v1.2 (see PRD §13 Q-3 backlog).
//
// This file is now a THIN DELEGATE that preserves the previous
// `KeychainService.shared.X` public API surface and forwards every call to
// `PrefsTokenStore.shared`. Existing callers compile unchanged.
//
// Real storage moves to:
//   ~/Library/Preferences/com.krzemienski.burrow.plist
// (managed by Sources/Preferences/PrefsTokenStore.swift)

import Foundation

// Preserve the error type as a typealias so any caller catching
// KeychainError.osstatus(_:) compiles. We never throw it from the delegate
// (the plist backend cannot fail with an OSStatus), but the symbol must
// exist for compatibility.
enum KeychainError: Error, LocalizedError {
    case osstatus(OSStatus)
    case backendUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .osstatus(let code):
            return "Legacy Keychain error: OSStatus \(code) (post-pivot — should not occur)"
        case .backendUnavailable(let why):
            return "Token store unavailable: \(why)"
        }
    }
}

/// Thin facade — all calls forward to `PrefsTokenStore.shared`.
/// Public API surface is identical to the pre-pivot Keychain implementation.
actor KeychainService {

    static let shared = KeychainService()

    private init() {}

    // MARK: - API token

    func setAPIToken(_ token: String) async throws {
        try await PrefsTokenStore.shared.setAPIToken(token)
    }

    func getAPIToken() async throws -> String? {
        try await PrefsTokenStore.shared.getAPIToken()
    }

    func deleteAPIToken() async throws {
        try await PrefsTokenStore.shared.deleteAPIToken()
    }

    // MARK: - Tunnel run tokens

    func setRunToken(_ token: String, tunnelID: String) async throws {
        try await PrefsTokenStore.shared.setRunToken(token, tunnelID: tunnelID)
    }

    func getRunToken(tunnelID: String) async throws -> String? {
        try await PrefsTokenStore.shared.getRunToken(tunnelID: tunnelID)
    }

    func deleteRunToken(tunnelID: String) async throws {
        try await PrefsTokenStore.shared.deleteRunToken(tunnelID: tunnelID)
    }

    // MARK: - Access service token (client_id + client_secret, keyed by appID)

    func setAccessServiceToken(clientID: String, clientSecret: String, appID: String) async throws {
        try await PrefsTokenStore.shared.setAccessServiceToken(
            clientID: clientID,
            clientSecret: clientSecret,
            appID: appID)
    }

    func getAccessServiceToken(appID: String) async throws -> (clientID: String, clientSecret: String)? {
        try await PrefsTokenStore.shared.getAccessServiceToken(appID: appID)
    }

    func deleteAccessServiceToken(appID: String) async throws {
        try await PrefsTokenStore.shared.deleteAccessServiceToken(appID: appID)
    }
}
