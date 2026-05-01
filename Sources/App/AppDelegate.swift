// AppDelegate.swift
// Burrow — NSApplicationDelegate adapter.
//
// D-H additions:
//   - Wire UNUserNotificationCenter (Notifier) at launch
//   - Auto-open Wizard if no API token, else auto-open Dashboard
//     (controlled by prefs.openDashboardAtLaunch)
//   - Listen for .burrowOpenDashboard NotificationCenter posts so the
//     Notifier action button can drive the SwiftUI Window scene open

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Notifier — request authorization + register categories
        Notifier.shared.requestAuthorization()
        Notifier.shared.registerCategories()

        // 2. Network monitor — start polling so Dashboard binds to live data
        NetworkMonitor.shared.start()

        // 3. Decide what window to open first
        Task { @MainActor in
            // try? wraps String? → String??; flatten then check for nil/empty
            let tokenOpt: String? = (try? await KeychainService.shared.getAPIToken()) ?? nil
            let hasToken = (tokenOpt?.isEmpty == false)
            if !hasToken {
                requestOpenWindow(id: "first-run")
            } else if PreferencesStore.shared.openDashboardAtLaunch {
                requestOpenWindow(id: "dashboard")
            }
        }

        // 4. Bridge UN action-button "Open Dashboard" → SwiftUI window
        NotificationCenter.default.addObserver(
            forName: .burrowOpenDashboard,
            object: nil,
            queue: .main
        ) { _ in
            self.requestOpenWindow(id: "dashboard")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // PRP §3.6 gotcha #11: ensure the cloudflared child is reaped synchronously.
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await CloudflaredManager.shared.stop()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
    }

    /// Request that the SwiftUI scene graph open the named window.
    /// A small helper view (BurrowOpenWindowBridge) listens via @Environment(\.openWindow).
    private func requestOpenWindow(id: String) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(
            name: .burrowRequestOpenWindow,
            object: nil,
            userInfo: ["id": id]
        )
    }
}

extension Notification.Name {
    /// AppDelegate posts this; a SwiftUI helper view subscribes and calls
    /// openWindow(id:) from its @Environment so the requested Window scene appears.
    static let burrowRequestOpenWindow = Notification.Name("burrow.requestOpenWindow")
}
