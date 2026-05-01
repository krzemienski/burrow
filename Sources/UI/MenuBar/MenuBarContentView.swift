// MenuBarContentView.swift
// Burrow — the menu that drops down from the menu bar icon.
//
// Phase 5 deliverable. Binds to CloudflaredManager state via PreferencesStore
// shared instances. Actions call CloudflaredManager via Task { await ... }.

import SwiftUI
import AppKit

struct MenuBarContentView: View {

    private let prefs = PreferencesStore.shared
    private let manager = CloudflaredManager.shared

    @State private var currentState: TunnelState = .idle
    @State private var uptimeString: String = ""
    @State private var copyConfirmed: Bool = false
    @State private var uptimeTimer: Timer? = nil

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // ── Status block ──────────────────────────────────────────────────
        statusSection

        Divider()

        // ── D-I: Open Dashboard (top action) ──────────────────────────────
        Button("Open Dashboard…") {
            openWindow(id: "dashboard")
        }
        .keyboardShortcut("d", modifiers: [.command])
        .accessibilityLabel("Open Dashboard window")

        Divider()

        // ── Hostname + copy actions ───────────────────────────────────────
        if let hostname = prefs.fullyQualifiedHostname {
            hostnameSection(hostname: hostname)
            Divider()
        }

        // ── Tunnel control ────────────────────────────────────────────────
        tunnelControls

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: [.command])
        .accessibilityLabel("Open Settings")

        Divider()

        Button("Quit Burrow") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
        .accessibilityLabel("Quit Burrow")
    }

    // MARK: - Status section

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                statusDot
                Text(stateLabel)
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            if !uptimeString.isEmpty {
                Text(uptimeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    @ViewBuilder
    private var statusDot: some View {
        switch currentState {
        case .running:
            Circle().fill(Color.green).frame(width: 8, height: 8)
        case .starting, .reconnecting:
            Circle().fill(Color.yellow).frame(width: 8, height: 8)
        case .failed:
            Circle().fill(Color.red).frame(width: 8, height: 8)
        default:
            Circle().fill(Color.secondary).frame(width: 8, height: 8)
        }
    }

    private var stateLabel: String {
        switch currentState {
        case .idle:                        return "idle"
        case .starting:                    return "starting…"
        case .running:                     return "tunnel up"
        case .reconnecting(let attempt):   return "reconnecting · attempt \(attempt)"
        case .failed(let reason):          return reason
        case .stopped:                     return "stopped"
        }
    }

    // MARK: - Hostname section

    @ViewBuilder
    private func hostnameSection(hostname: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(hostname)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    copyToClipboard(hostname)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy hostname")
            }

            Button {
                copySSHCommand(hostname: hostname)
            } label: {
                HStack {
                    Image(systemName: copyConfirmed ? "checkmark" : "terminal")
                        .imageScale(.small)
                    Text(copyConfirmed ? "Copied!" : "Copy SSH command")
                }
            }
            .keyboardShortcut("c", modifiers: [.command])
            .accessibilityLabel("Copy SSH command to clipboard")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tunnel controls

    @ViewBuilder
    private var tunnelControls: some View {
        switch currentState {
        case .stopped, .idle, .failed:
            Button("Start Tunnel") {
                startTunnel()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .accessibilityLabel("Start tunnel")

        case .running:
            Button("Stop Tunnel") {
                Task { await manager.stop() }
            }
            .keyboardShortcut(".", modifiers: [.command])
            .accessibilityLabel("Stop tunnel")

            Button("Restart Tunnel") {
                restartTunnel()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .accessibilityLabel("Restart tunnel")

        case .starting, .reconnecting:
            Button("Stop") {
                Task { await manager.stop() }
            }
            .accessibilityLabel("Stop tunnel")
        }
    }

    // MARK: - Actions

    private func startTunnel() {
        guard let tunnelID = prefs.tunnelID else { return }
        Task {
            do {
                let runToken = try await KeychainService.shared.getRunToken(tunnelID: tunnelID)
                guard let token = runToken else { return }
                try await manager.start(runToken: token)
            } catch {
                // State transitions to .failed inside the manager
            }
        }
    }

    private func restartTunnel() {
        guard let tunnelID = prefs.tunnelID else { return }
        Task {
            do {
                let runToken = try await KeychainService.shared.getRunToken(tunnelID: tunnelID)
                guard let token = runToken else { return }
                try await manager.restart(runToken: token)
            } catch {
                // State transitions to .failed inside the manager
            }
        }
    }

    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func copySSHCommand(hostname: String) {
        let cmd = "ssh \(prefs.sshUsername)@\(hostname)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        withAnimation {
            copyConfirmed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copyConfirmed = false }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        refreshState()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refreshState()
        }
        uptimeTimer = t
    }

    private func stopPolling() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
    }

    private func refreshState() {
        Task { @MainActor in
            let s = await manager.state
            currentState = s
            if case .running(_, _, let since) = s {
                uptimeString = uptimeLabel(since: since)
            } else {
                uptimeString = ""
            }
        }
    }

    private func uptimeLabel(since: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(since))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
