// GeneralTab.swift
// Burrow — Settings → General.
// PRP §FR-5.1.

import SwiftUI
import ServiceManagement
import AppKit

struct GeneralTab: View {

    private let prefs = PreferencesStore.shared

    @State private var launchAtLogin: Bool = false
    @State private var notificationsEnabled: Bool = true
    @State private var logLevel: String = "info"
    @State private var launchAtLoginError: String? = nil
    @State private var loginItemStatus: SMAppService.Status = .notRegistered

    private let logLevels = ["debug", "info", "error"]

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .accessibilityLabel("Launch Burrow at login")
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLaunchAtLogin(newValue)
                    }

                if let err = launchAtLoginError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if loginItemStatus == .requiresApproval {
                    Button("Open Login Items in System Settings") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
                        NSWorkspace.shared.open(url)
                    }
                    .font(.caption)
                    .accessibilityLabel("Open Login Items settings to approve Burrow")
                }
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .accessibilityLabel("Enable tunnel status notifications")
                    .onChange(of: notificationsEnabled) { _, newValue in
                        prefs.notificationsEnabled = newValue
                    }
            }

            Section("Logging") {
                Picker("Log level", selection: $logLevel) {
                    ForEach(logLevels, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .accessibilityLabel("Log level picker")
                .onChange(of: logLevel) { _, newValue in
                    prefs.logLevel = newValue
                }
            }

            Section("Documentation") {
                Button("Open documentation") {
                    DocsDeepLink.openDocs()
                }
                .accessibilityLabel("Open Burrow documentation in browser")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = prefs.launchAtLogin
            notificationsEnabled = prefs.notificationsEnabled
            logLevel = prefs.logLevel
            loginItemStatus = SMAppService.mainApp.status
        }
    }

    // MARK: - Launch at login

    private func applyLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        let svc = SMAppService.mainApp
        do {
            if enabled {
                try svc.register()
            } else {
                try svc.unregister()
            }
            prefs.launchAtLogin = enabled
            loginItemStatus = svc.status
        } catch {
            launchAtLoginError = error.localizedDescription
            // Revert toggle on failure
            launchAtLogin = !enabled
        }
    }
}
