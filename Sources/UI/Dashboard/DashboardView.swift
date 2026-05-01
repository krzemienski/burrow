// DashboardView.swift
// Burrow — primary user-facing surface fusing status + control + inline config.
//
// Spec: UX-GAP-ANALYSIS.md §3 mockup, §7 phase D-A.
// Brand: BRAND.md §3 (cyber orange on bean-1) + §7 (hard cuts only, 0.16s linear).
//
// Architecture:
//   - DashboardView holds @State observers for tunnel state, metrics, network.
//   - 1s Timer ticks the uptime label (same pattern as MenuBarContentView lines 213-236).
//   - State changes from CloudflaredManager.stateStream() drive Notifier events.

import SwiftUI
import AppKit

struct DashboardView: View {

    // ── Observers ───────────────────────────────────────────────────────
    @State private var observer = TunnelStateObserver()
    @State private var metrics = MetricsClient.shared
    @State private var network = NetworkMonitor.shared

    private let prefs = PreferencesStore.shared

    // ── Local UI state ──────────────────────────────────────────────────
    @State private var uptimeString: String = ""
    @State private var uptimeTimer: Timer? = nil
    @State private var copyConfirmed: Bool = false

    @State private var showSubdomainEditor: Bool = false
    @State private var showUsernameEditor: Bool = false
    @State private var showDiagnostics: Bool = false

    @State private var lastObservedState: TunnelState = .idle

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            BrandColor.bean1.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header
                heroHostname
                middleRow
                recentActivity
                networkRow
                footerActionRow
            }
            .padding(24)
        }
        .frame(width: 800, height: 560)
        .preferredColorScheme(.dark)
        .onAppear {
            observer.start()
            network.start()
            startUptimeTimer()
            adjustMetricsPolling(for: observer.state)
        }
        .onDisappear {
            observer.stop()
            stopUptimeTimer()
            metrics.stop()
        }
        .onChange(of: observer.state) { old, new in
            withAnimation(.linear(duration: 0.16)) {
                lastObservedState = new
                refreshUptime()
            }
            adjustMetricsPolling(for: new)
            fireNotificationsForTransition(old: old, new: new)
        }
        .sheet(isPresented: $showSubdomainEditor) {
            SubdomainEditorPopover {
                showSubdomainEditor = false
            }
        }
        .sheet(isPresented: $showUsernameEditor) {
            SSHUsernameEditorPopover {
                showUsernameEditor = false
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsSheet {
                showDiagnostics = false
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Circle()
                    .fill(BrandColor.orange)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(BrandColor.bean1)
                            .frame(width: 8, height: 8)
                    )
                    .accessibilityHidden(true)
                Text("burrow")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(BrandColor.cream)
                    .tracking(-1.5)
            }

            Spacer()

            statePill
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statePill: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(BrandColor.pillText(for: observer.state))
                    .frame(width: 8, height: 8)
                Text(stateLabel(observer.state))
                    .font(BrandFont.label)
                    .foregroundStyle(BrandColor.pillText(for: observer.state))
                    .tracking(2.0)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BrandColor.pill(for: observer.state))
            .clipShape(Capsule())
            .accessibilityIdentifier("dashboard.statePill")
            .accessibilityLabel("Tunnel state: \(stateLabel(observer.state))")

            if !uptimeString.isEmpty {
                Text(uptimeString + " up")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.cream2)
                    .accessibilityIdentifier("dashboard.uptime")
            }
        }
    }

    // MARK: - Hero hostname block

    @ViewBuilder
    private var heroHostname: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(prefs.fullyQualifiedHostname ?? "no hostname configured")
                    .font(BrandFont.headline)
                    .foregroundStyle(BrandColor.cream)
                    .accessibilityIdentifier("dashboard.hostname")
                Spacer()
                Button {
                    showSubdomainEditor = true
                } label: {
                    Label("edit", systemImage: "pencil")
                        .font(BrandFont.label)
                        .tracking(2.0)
                        .textCase(.uppercase)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BrandColor.orange)
                .accessibilityIdentifier("dashboard.editHostname")
                .accessibilityLabel("Edit subdomain")
            }

            HStack {
                Text(prefs.sshCommand ?? "ssh \(prefs.sshUsername)@<hostname>")
                    .font(BrandFont.monoLg)
                    .foregroundStyle(BrandColor.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandColor.bean3)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("dashboard.sshCommand")

                Button {
                    copySSH()
                } label: {
                    Image(systemName: copyConfirmed ? "checkmark" : "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(BrandColor.cream)
                        .padding(10)
                        .background(BrandColor.bean4)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: [.command])
                .accessibilityIdentifier("dashboard.copySSH")
                .accessibilityLabel("Copy SSH command")

                Button {
                    showUsernameEditor = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundStyle(BrandColor.cream)
                        .padding(10)
                        .background(BrandColor.bean4)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dashboard.editUsername")
                .accessibilityLabel("Edit SSH username")
            }
        }
    }

    // MARK: - Middle row (QR + metrics card)

    @ViewBuilder
    private var middleRow: some View {
        HStack(alignment: .top, spacing: 16) {
            qrCard
            metricsCard
        }
    }

    @ViewBuilder
    private var qrCard: some View {
        VStack(spacing: 8) {
            if let cmd = prefs.sshCommand, let qr = QRCode.make(string: cmd, size: CGSize(width: 140, height: 140)) {
                qr
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 140, height: 140)
                    .accessibilityIdentifier("dashboard.qrCode")
                    .accessibilityLabel("QR code for SSH command")
            } else {
                Rectangle()
                    .fill(BrandColor.bean3)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Text("no hostname")
                            .font(BrandFont.mono)
                            .foregroundStyle(BrandColor.bean6)
                    )
            }
            Text("scan to ssh")
                .font(BrandFont.label)
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(BrandColor.cream2)
        }
        .padding(12)
        .background(BrandColor.bean2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 24) {
                metricCell(label: "EDGES",     value: "\(metrics.snapshot.edges.count)")
                metricCell(label: "ACTIVE",    value: "\(metrics.snapshot.activeStreams)")
                metricCell(label: "↓ KB",      value: "\(metrics.snapshot.bytesIn / 1024)")
                metricCell(label: "↑ KB",      value: "\(metrics.snapshot.bytesOut / 1024)")
                metricCell(label: "REQUESTS",  value: "\(metrics.snapshot.totalRequests)")
            }

            if let edge = metrics.snapshot.edges.keys.sorted().first {
                Text("\(edge) · \(metrics.snapshot.edges.count) connection(s)")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.cream2)
            } else if metrics.snapshot.lastError != nil {
                Text("metrics unavailable")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.bean6)
            } else {
                Text("waiting for metrics…")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.bean6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(BrandColor.bean2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("dashboard.metricsCard")
    }

    @ViewBuilder
    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(BrandFont.label)
                .tracking(2.0)
                .foregroundStyle(BrandColor.cream2)
            Text(value)
                .font(BrandFont.title)
                .foregroundStyle(BrandColor.cream)
        }
    }

    // MARK: - Recent activity (D-C)

    @ViewBuilder
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent activity")
                    .font(BrandFont.label)
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColor.cream2)
                Spacer()
                Text("\(observer.recentLines.count) lines")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.bean6)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(observer.recentLines.suffix(50)) { line in
                            HStack(spacing: 6) {
                                Text(line.timestamp, style: .time)
                                    .font(BrandFont.mono)
                                    .foregroundStyle(BrandColor.bean6)
                                Text(line.line)
                                    .font(BrandFont.mono)
                                    .foregroundStyle(severityColor(line.severity))
                                    .textSelection(.enabled)
                            }
                            .id(line.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if observer.recentLines.isEmpty {
                            Text("— waiting for tunnel logs —")
                                .font(BrandFont.mono)
                                .foregroundStyle(BrandColor.bean6)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 110)
                .background(BrandColor.bean3)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityIdentifier("dashboard.recentActivity")
                .onChange(of: observer.recentLines.count) { _, _ in
                    if let last = observer.recentLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func severityColor(_ s: TunnelLogLine.Severity) -> Color {
        switch s {
        case .error:    return BrandColor.magenta
        case .warn:     return BrandColor.orangeHot
        case .info:     return BrandColor.cream
        }
    }

    // MARK: - Network row (D-G)

    @ViewBuilder
    private var networkRow: some View {
        HStack(spacing: 8) {
            Image(systemName: network.isSatisfied ? "wifi" : "wifi.slash")
                .foregroundStyle(network.isSatisfied ? BrandColor.acid : BrandColor.magenta)
            Text(network.isSatisfied ? "online" : "offline")
                .font(BrandFont.body)
                .foregroundStyle(BrandColor.cream)
            if let ssid = network.currentSSID {
                Text("· \(ssid)")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.cream2)
            }
            Text("·")
                .foregroundStyle(BrandColor.bean6)
            Text("Local SSH on :\(prefs.localPort)")
                .font(BrandFont.mono)
                .foregroundStyle(BrandColor.cream2)
            Image(systemName: network.isLocalSSHListening ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(network.isLocalSSHListening ? BrandColor.acid : BrandColor.bean6)

            Spacer()

            Button {
                showDiagnostics = true
            } label: {
                Label("test from outside", systemImage: "questionmark.circle")
                    .font(BrandFont.label)
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColor.orange)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard.diagnosticsButton")
        }
    }

    // MARK: - Footer action row

    @ViewBuilder
    private var footerActionRow: some View {
        HStack(spacing: 12) {
            stopRestartButtons
            Spacer()
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
                    .font(BrandFont.body)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(BrandColor.bean3)
            .foregroundStyle(BrandColor.cream)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .keyboardShortcut(",", modifiers: [.command])
            .accessibilityIdentifier("dashboard.settingsButton")

            Button {
                showDiagnostics = true
            } label: {
                Label("Diagnostics", systemImage: "stethoscope")
                    .font(BrandFont.body)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(BrandColor.bean3)
                    .foregroundStyle(BrandColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .accessibilityIdentifier("dashboard.diagnosticsFooterButton")
        }
    }

    @ViewBuilder
    private var stopRestartButtons: some View {
        switch observer.state {
        case .stopped, .idle, .failed:
            Button {
                startTunnel()
            } label: {
                Label("Start Tunnel", systemImage: "play.fill")
                    .font(BrandFont.body)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(BrandColor.orange)
                    .foregroundStyle(BrandColor.bean1)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard.startButton")

        case .running:
            Button {
                Task { await CloudflaredManager.shared.stop() }
            } label: {
                Label("Stop Tunnel", systemImage: "stop.fill")
                    .font(BrandFont.body)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(BrandColor.magenta)
                    .foregroundStyle(BrandColor.bean1)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(".", modifiers: [.command])
            .accessibilityIdentifier("dashboard.stopButton")

            Button {
                restartTunnel()
            } label: {
                Label("Restart", systemImage: "arrow.clockwise")
                    .font(BrandFont.body)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(BrandColor.bean3)
                    .foregroundStyle(BrandColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: [.command])
            .accessibilityIdentifier("dashboard.restartButton")

        case .starting, .reconnecting:
            Button {
                Task { await CloudflaredManager.shared.stop() }
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(BrandFont.body)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(BrandColor.bean3)
                    .foregroundStyle(BrandColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard.stopButton")
        }
    }

    // MARK: - Helpers

    private func stateLabel(_ s: TunnelState) -> String {
        switch s {
        case .idle:                       return "idle"
        case .starting:                   return "starting"
        case .running:                    return "running"
        case .reconnecting(let attempt):  return "reconnecting · \(attempt)"
        case .failed:                     return "failed"
        case .stopped:                    return "stopped"
        }
    }

    private func startTunnel() {
        guard let tunnelID = prefs.tunnelID else { return }
        Task {
            if let token = try? await KeychainService.shared.getRunToken(tunnelID: tunnelID) {
                try? await CloudflaredManager.shared.start(runToken: token)
            }
        }
    }

    private func restartTunnel() {
        guard let tunnelID = prefs.tunnelID else { return }
        Task {
            if let token = try? await KeychainService.shared.getRunToken(tunnelID: tunnelID) {
                try? await CloudflaredManager.shared.restart(runToken: token)
            }
        }
    }

    private func copySSH() {
        guard let cmd = prefs.sshCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        withAnimation(.linear(duration: 0.16)) {
            copyConfirmed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.linear(duration: 0.16)) { copyConfirmed = false }
        }
    }

    private func startUptimeTimer() {
        refreshUptime()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refreshUptime()
        }
        uptimeTimer = t
    }

    private func stopUptimeTimer() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
    }

    private func refreshUptime() {
        if case .running(_, _, let since) = observer.state {
            let elapsed = Int(Date().timeIntervalSince(since))
            let h = elapsed / 3600
            let m = (elapsed % 3600) / 60
            let s = elapsed % 60
            uptimeString = h > 0 ? "\(h)h \(m)m" : (m > 0 ? "\(m)m \(s)s" : "\(s)s")
        } else {
            uptimeString = ""
        }
    }

    private func adjustMetricsPolling(for state: TunnelState) {
        if case .running = state {
            metrics.start()
        } else {
            metrics.stop()
        }
    }

    private func fireNotificationsForTransition(old: TunnelState, new: TunnelState) {
        switch (old, new) {
        case (.starting, .running):
            if let host = prefs.fullyQualifiedHostname {
                Notifier.shared.fire(.tunnelUp(hostname: host, sshUser: prefs.sshUsername))
            }
        case (.running, .stopped):
            Notifier.shared.fire(.tunnelDown)
        case (_, .reconnecting(let attempt)):
            Notifier.shared.fire(.reconnecting(attempt: attempt))
        case (_, .failed):
            Notifier.shared.fire(.tunnelDown)
        default:
            break
        }
    }
}
