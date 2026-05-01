// PreferencesStore.swift
// Burrow — Observable wrapper around UserDefaults.
//
// Persists non-secret state across launches. Secrets go to Keychain.
// Suite: "com.krzemienski.burrow", key prefix: "burrow."

import Foundation
import Observation

@Observable
final class PreferencesStore {

    static let shared = PreferencesStore()

    // MARK: - UserDefaults suite

    private let defaults: UserDefaults

    // MARK: - Cloudflare identifiers

    var selectedAccountID: String? {
        didSet { defaults.set(selectedAccountID, forKey: Keys.selectedAccountID) }
    }

    var selectedZoneID: String? {
        didSet { defaults.set(selectedZoneID, forKey: Keys.selectedZoneID) }
    }

    var selectedZoneName: String? {
        didSet { defaults.set(selectedZoneName, forKey: Keys.selectedZoneName) }
    }

    var subdomain: String {
        didSet { defaults.set(subdomain, forKey: Keys.subdomain) }
    }

    // MARK: - Tunnel identifiers

    var tunnelID: String? {
        didSet { defaults.set(tunnelID, forKey: Keys.tunnelID) }
    }

    var tunnelName: String? {
        didSet { defaults.set(tunnelName, forKey: Keys.tunnelName) }
    }

    // MARK: - Cloudflare Access (set by BurrowE2E setup)

    var accessAppID: String? {
        didSet { defaults.set(accessAppID, forKey: Keys.accessAppID) }
    }

    var accessServiceTokenID: String? {
        didSet { defaults.set(accessServiceTokenID, forKey: Keys.accessServiceTokenID) }
    }

    var accessPolicyID: String? {
        didSet { defaults.set(accessPolicyID, forKey: Keys.accessPolicyID) }
    }

    // MARK: - SSH

    var localPort: Int {
        didSet { defaults.set(localPort, forKey: Keys.localPort) }
    }

    var sshUsername: String {
        didSet { defaults.set(sshUsername, forKey: Keys.sshUsername) }
    }

    // MARK: - System

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    /// D-H — when true, present the Dashboard window on app launch (after wizard if needed).
    /// Defaults to true. User can flip in Settings → General.
    var openDashboardAtLaunch: Bool {
        didSet { defaults.set(openDashboardAtLaunch, forKey: Keys.openDashboardAtLaunch) }
    }

    var logLevel: String {
        didSet { defaults.set(logLevel, forKey: Keys.logLevel) }
    }

    // MARK: - Advanced overrides

    var customCloudflaredPath: String? {
        didSet { defaults.set(customCloudflaredPath, forKey: Keys.customCloudflaredPath) }
    }

    // MARK: - Computed

    var fullyQualifiedHostname: String? {
        guard let zone = selectedZoneName, !subdomain.isEmpty else { return nil }
        return "\(subdomain).\(zone)"
    }

    var sshCommand: String? {
        guard let host = fullyQualifiedHostname else { return nil }
        return "ssh \(sshUsername)@\(host)"
    }

    // MARK: - Init

    private init() {
        let suite = UserDefaults(suiteName: "com.krzemienski.burrow") ?? .standard
        self.defaults = suite

        // Hydrate stored values; fall back to compile-time defaults.
        selectedAccountID   = suite.string(forKey: Keys.selectedAccountID)
        selectedZoneID      = suite.string(forKey: Keys.selectedZoneID)
        selectedZoneName    = suite.string(forKey: Keys.selectedZoneName)
        subdomain           = suite.string(forKey: Keys.subdomain) ?? "m4"
        tunnelID            = suite.string(forKey: Keys.tunnelID)
        tunnelName          = suite.string(forKey: Keys.tunnelName)
        localPort           = suite.object(forKey: Keys.localPort) != nil
                                ? suite.integer(forKey: Keys.localPort) : 22
        sshUsername         = suite.string(forKey: Keys.sshUsername) ?? NSUserName()
        launchAtLogin       = suite.bool(forKey: Keys.launchAtLogin)
        notificationsEnabled = suite.object(forKey: Keys.notificationsEnabled) != nil
                                ? suite.bool(forKey: Keys.notificationsEnabled) : true
        openDashboardAtLaunch = suite.object(forKey: Keys.openDashboardAtLaunch) != nil
                                ? suite.bool(forKey: Keys.openDashboardAtLaunch) : true
        logLevel            = suite.string(forKey: Keys.logLevel) ?? "info"
        customCloudflaredPath = suite.string(forKey: Keys.customCloudflaredPath)
        accessAppID           = suite.string(forKey: Keys.accessAppID)
        accessServiceTokenID  = suite.string(forKey: Keys.accessServiceTokenID)
        accessPolicyID        = suite.string(forKey: Keys.accessPolicyID)
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let selectedAccountID    = "burrow.selectedAccountID"
        static let selectedZoneID       = "burrow.selectedZoneID"
        static let selectedZoneName     = "burrow.selectedZoneName"
        static let subdomain            = "burrow.subdomain"
        static let tunnelID             = "burrow.tunnelID"
        static let tunnelName           = "burrow.tunnelName"
        static let localPort            = "burrow.localPort"
        static let sshUsername          = "burrow.sshUsername"
        static let launchAtLogin        = "burrow.launchAtLogin"
        static let notificationsEnabled = "burrow.notificationsEnabled"
        static let openDashboardAtLaunch = "burrow.openDashboardAtLaunch"
        static let logLevel             = "burrow.logLevel"
        static let customCloudflaredPath = "burrow.customCloudflaredPath"
        static let accessAppID           = "burrow.accessAppID"
        static let accessServiceTokenID  = "burrow.accessServiceTokenID"
        static let accessPolicyID        = "burrow.accessPolicyID"
    }
}
