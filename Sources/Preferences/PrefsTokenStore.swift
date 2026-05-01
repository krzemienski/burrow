// PrefsTokenStore.swift
// Burrow — UserDefaults-backed token store (plist on disk).
//
// PIVOT NOTE (2026-05-01): User mandated dropping Keychain in favor of plist
// (UserDefaults) to avoid macOS Keychain authorization prompts during dev
// iteration. CLAUDE.md §3 "API token lives only in Keychain" is overridden
// for this iter — production hardening to migrate back to Keychain in v1.2.
//
// Storage location:
//   ~/Library/Preferences/com.krzemienski.burrow.plist
//
// Keys:
//   burrow.token.api                            → API token (single)
//   burrow.token.run.<tunnelID>                 → per-tunnel run-token
//   burrow.token.access.svc.client_id.<appID>   → Access service-token client_id
//   burrow.token.access.svc.client_secret.<appID> → Access service-token secret
//
// Same public API surface as the previous KeychainService actor — drop-in
// replacement so existing callers (BurrowE2E, WizardCoordinator,
// CloudflareTab, AppDelegate) continue to compile via the KeychainService
// shim that delegates here.

import Foundation

actor PrefsTokenStore {

    static let shared = PrefsTokenStore()

    private let suiteName = "com.krzemienski.burrow"
    private let defaults: UserDefaults

    private init() {
        // UserDefaults(suiteName:) returns nil when the suite name matches the
        // app's own bundle identifier (the case in the Burrow.app target).
        // Fall back to .standard so the app launches; the BurrowE2E CLI target
        // (different bundle id) keeps the suite-scoped store.
        self.defaults = UserDefaults(suiteName: "com.krzemienski.burrow") ?? .standard
    }

    // MARK: - API token (single instance per app)

    func setAPIToken(_ token: String) async throws {
        Log.keychain.info("Prefs set api-token len=\(token.count, privacy: .public)")
        defaults.set(token, forKey: "burrow.token.api")
    }

    func getAPIToken() async throws -> String? {
        defaults.string(forKey: "burrow.token.api")
    }

    func deleteAPIToken() async throws {
        Log.keychain.info("Prefs delete api-token")
        defaults.removeObject(forKey: "burrow.token.api")
    }

    // MARK: - Tunnel run tokens (one per tunnel, indexed by tunnel ID)

    func setRunToken(_ token: String, tunnelID: String) async throws {
        Log.keychain.info("Prefs set run-token tunnelID=\(tunnelID, privacy: .public) len=\(token.count, privacy: .public)")
        defaults.set(token, forKey: "burrow.token.run.\(tunnelID)")
    }

    func getRunToken(tunnelID: String) async throws -> String? {
        defaults.string(forKey: "burrow.token.run.\(tunnelID)")
    }

    func deleteRunToken(tunnelID: String) async throws {
        Log.keychain.info("Prefs delete run-token tunnelID=\(tunnelID, privacy: .public)")
        defaults.removeObject(forKey: "burrow.token.run.\(tunnelID)")
    }

    // MARK: - Access service token (client_id + client_secret, keyed by appID)

    func setAccessServiceToken(clientID: String, clientSecret: String, appID: String) async throws {
        Log.keychain.info("Prefs set access svc token for app: \(appID, privacy: .public)")
        defaults.set(clientID, forKey: "burrow.token.access.svc.client_id.\(appID)")
        defaults.set(clientSecret, forKey: "burrow.token.access.svc.client_secret.\(appID)")
    }

    func getAccessServiceToken(appID: String) async throws -> (clientID: String, clientSecret: String)? {
        guard
            let cid = defaults.string(forKey: "burrow.token.access.svc.client_id.\(appID)"),
            let csc = defaults.string(forKey: "burrow.token.access.svc.client_secret.\(appID)")
        else { return nil }
        return (clientID: cid, clientSecret: csc)
    }

    func deleteAccessServiceToken(appID: String) async throws {
        Log.keychain.info("Prefs delete access svc token for app: \(appID, privacy: .public)")
        defaults.removeObject(forKey: "burrow.token.access.svc.client_id.\(appID)")
        defaults.removeObject(forKey: "burrow.token.access.svc.client_secret.\(appID)")
    }

    // MARK: - Bulk wipe (used by teardown)

    func wipeAll() async throws {
        Log.keychain.info("Prefs wipe ALL token keys")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("burrow.token.") {
            defaults.removeObject(forKey: key)
        }
    }
}
