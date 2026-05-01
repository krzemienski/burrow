// CFTunnelApp.swift
// Burrow — entry point and scene graph.
//
// Phase 1 deliverable: this file renders a MenuBarExtra in the macOS menu bar
// with no Dock icon (LSUIElement=YES in Info.plist) and a Settings scene.
//
// D-I additions: Dashboard window scene + a tiny bridge view that listens
// for AppDelegate's `.burrowRequestOpenWindow` notifications and calls
// openWindow(id:) from the SwiftUI environment.

import SwiftUI

@main
struct BurrowApp: App {

    // Adapter for NSApplicationDelegate-only APIs (sleep/wake, willTerminate).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // ---------- Menu bar ----------
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            // Phase 4: switch system image based on TunnelState.
            ZStack {
                Image(systemName: "network.slash")
                BurrowOpenWindowBridge()  // invisible; bridges AppDelegate → openWindow
            }
        }
        .menuBarExtraStyle(.menu)

        // ---------- Settings window ----------
        Settings {
            SettingsView()
        }

        // ---------- Dashboard window (D-I) ----------
        Window("Dashboard", id: "dashboard") {
            DashboardView()
        }
        .windowResizability(.contentSize)

        // ---------- First-run wizard ----------
        Window("Welcome to Burrow", id: "first-run") {
            WizardCoordinatorView {
                // Window dismisses via system close button
            }
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Open-window bridge

/// Invisible SwiftUI view that lives inside the menu-bar label so it's always
/// mounted. Listens for `.burrowRequestOpenWindow` notifications posted by
/// AppDelegate and calls openWindow(id:) from the SwiftUI environment.
private struct BurrowOpenWindowBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .burrowRequestOpenWindow)) { note in
                if let id = note.userInfo?["id"] as? String {
                    openWindow(id: id)
                }
            }
    }
}
