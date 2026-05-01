// Notifier.swift
// Burrow — UNUserNotificationCenter wrapper.
//
// PRP §FR-7 (mandatory). UX-GAP §6 table maps each NotifierEvent to its body,
// sound, and action category.
//
// AppDelegate.applicationDidFinishLaunching calls:
//   Notifier.shared.requestAuthorization()
//   Notifier.shared.registerCategories()
// Then anywhere you have an interesting state transition:
//   Notifier.shared.fire(.tunnelUp(hostname: "m4.hack.ski", sshUser: "nick"))

import Foundation
import UserNotifications
import AppKit
import OSLog

// MARK: - Event taxonomy

enum NotifierEvent {
    case tunnelUp(hostname: String, sshUser: String)
    case tunnelDown
    case reconnecting(attempt: Int)
    case tokenRevoked
    case insufficientScope(missing: String)
    case firstSuccess(hostname: String, sshUser: String)
}

// MARK: - Notifier

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {

    static let shared = Notifier()

    private let center = UNUserNotificationCenter.current()
    private var authorized: Bool = false

    // Action / category identifiers — referenced from registerCategories()
    // and matched by the system when the user clicks an action button.
    private enum CategoryID {
        static let tunnelUp        = "BURROW_TUNNEL_UP"
        static let tunnelDown      = "BURROW_TUNNEL_DOWN"
        static let reconnecting    = "BURROW_RECONNECTING"
        static let tokenRevoked    = "BURROW_TOKEN_REVOKED"
        static let scopeMissing    = "BURROW_SCOPE_MISSING"
        static let firstSuccess    = "BURROW_FIRST_SUCCESS"
    }

    private enum ActionID {
        static let copySSH               = "BURROW_COPY_SSH"
        static let restart               = "BURROW_RESTART"
        static let openDashboard         = "BURROW_OPEN_DASHBOARD"
        static let openSettingsCloudflare = "BURROW_OPEN_SETTINGS_CF"
        static let openCloudflareDash    = "BURROW_OPEN_CF_DASH"
    }

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    /// Ask the OS for permission. Idempotent — if the user already granted
    /// or denied, this resolves immediately with the existing state.
    func requestAuthorization() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.authorized = granted
                if let error {
                    Log.lifecycle.error("UN authorization error: \(error.localizedDescription, privacy: .public)")
                } else {
                    Log.lifecycle.info("UN authorization granted=\(granted, privacy: .public)")
                }
            }
        }
    }

    /// Register all notification categories + action buttons.
    /// Must be called once at app launch, after requestAuthorization.
    func registerCategories() {
        let copySSH = UNNotificationAction(identifier: ActionID.copySSH, title: "Copy SSH", options: [])
        let restart = UNNotificationAction(identifier: ActionID.restart, title: "Restart", options: [])
        let openDash = UNNotificationAction(identifier: ActionID.openDashboard, title: "Open Dashboard", options: [.foreground])
        let openSettingsCF = UNNotificationAction(identifier: ActionID.openSettingsCloudflare, title: "Open Settings", options: [.foreground])
        let openCFDash = UNNotificationAction(identifier: ActionID.openCloudflareDash, title: "Open Cloudflare Dashboard", options: [.foreground])

        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: CategoryID.tunnelUp,
                                    actions: [copySSH, openDash], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: CategoryID.tunnelDown,
                                    actions: [restart], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: CategoryID.reconnecting,
                                    actions: [openDash], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: CategoryID.tokenRevoked,
                                    actions: [openSettingsCF], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: CategoryID.scopeMissing,
                                    actions: [openCFDash], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: CategoryID.firstSuccess,
                                    actions: [copySSH], intentIdentifiers: [], options: []),
        ]
        center.setNotificationCategories(categories)
        Log.lifecycle.info("UN categories registered count=\(categories.count, privacy: .public)")
    }

    // MARK: - Fire

    /// Schedule + deliver a notification immediately. No-op if the user has
    /// notifications disabled in Settings → General.
    func fire(_ event: NotifierEvent) {
        guard PreferencesStore.shared.notificationsEnabled else {
            Log.lifecycle.info("Notifier suppressed — notificationsEnabled=false")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Burrow"

        switch event {
        case .tunnelUp(let host, let user):
            content.body = "\(host) is live. ssh \(user)@\(host)"
            content.categoryIdentifier = CategoryID.tunnelUp

        case .tunnelDown:
            content.body = "Tunnel stopped. Click to restart."
            content.categoryIdentifier = CategoryID.tunnelDown

        case .reconnecting(let attempt):
            content.body = "Lost connection. Reconnecting (attempt \(attempt))…"
            content.categoryIdentifier = CategoryID.reconnecting

        case .tokenRevoked:
            content.body = "Cloudflare token revoked. Re-enter in Settings."
            content.sound = UNNotificationSound(named: UNNotificationSoundName("Submarine.aiff"))
            content.categoryIdentifier = CategoryID.tokenRevoked

        case .insufficientScope(let missing):
            content.body = "Token missing scope: \(missing). Re-create token."
            content.sound = UNNotificationSound(named: UNNotificationSoundName("Submarine.aiff"))
            content.categoryIdentifier = CategoryID.scopeMissing

        case .firstSuccess(let host, let user):
            content.body = "Burrow ready. Try it: ssh \(user)@\(host)"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("Glass.aiff"))
            content.categoryIdentifier = CategoryID.firstSuccess
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // immediate
        )
        center.add(request) { error in
            if let error {
                Log.lifecycle.error("UN add failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification,
                                  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner + sound even when app is in foreground.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  didReceive response: UNNotificationResponse,
                                  withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }

        let prefs = PreferencesStore.shared

        switch response.actionIdentifier {
        case ActionID.copySSH:
            if let host = prefs.fullyQualifiedHostname {
                let cmd = "ssh \(prefs.sshUsername)@\(host)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(cmd, forType: .string)
            }

        case ActionID.restart:
            Task { @MainActor in
                guard let tid = prefs.tunnelID else { return }
                if let token = try? await KeychainService.shared.getRunToken(tunnelID: tid) {
                    try? await CloudflaredManager.shared.restart(runToken: token)
                }
            }

        case ActionID.openDashboard:
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .burrowOpenDashboard, object: nil)

        case ActionID.openSettingsCloudflare:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        case ActionID.openCloudflareDash:
            if let url = URL(string: "https://dash.cloudflare.com/profile/api-tokens") {
                NSWorkspace.shared.open(url)
            }

        case UNNotificationDefaultActionIdentifier:
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .burrowOpenDashboard, object: nil)

        default:
            break
        }
    }
}

extension Notification.Name {
    /// Posted when the user clicks "Open Dashboard" on a system notification.
    /// Observed by AppDelegate → triggers SwiftUI Window scene open via openWindow.
    static let burrowOpenDashboard = Notification.Name("burrow.openDashboard")
}
