// DashboardInlineEditors.swift
// Burrow — small inline config popovers presented from the Dashboard.
//
// Spec: UX-GAP-ANALYSIS.md §3 (inline configure on Dashboard) + Phase D-B.
//
// Subdomain editor:
//   - Updates PreferencesStore.subdomain
//   - Calls CloudflareClient.updateCNAME() to repoint the DNS record
//   - Restarts CloudflaredManager so the tunnel re-registers with the new hostname
//
// SSH-username editor:
//   - Updates PreferencesStore.sshUsername
//   - No API call required — purely local
//
// Diagnostics sheet:
//   - Runs SelfTest.runSelfTest(hostname:) and shows progress + result table

import SwiftUI

// MARK: - Subdomain editor

struct SubdomainEditorPopover: View {

    var onDismiss: () -> Void

    private let prefs = PreferencesStore.shared

    @State private var draftSubdomain: String = ""
    @State private var saving: Bool = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit subdomain")
                .font(BrandFont.title)
                .foregroundStyle(BrandColor.cream)

            HStack(spacing: 4) {
                TextField("subdomain", text: $draftSubdomain)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .accessibilityIdentifier("editor.subdomainField")
                Text(".\(prefs.selectedZoneName ?? "<no zone>")")
                    .font(BrandFont.monoLg)
                    .foregroundStyle(BrandColor.cream2)
            }

            if let error {
                Text(error)
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.magenta)
            }

            Text("Saving will update the Cloudflare CNAME record and restart the tunnel. The hostname will be unreachable for ~10 seconds.")
                .font(BrandFont.mono)
                .foregroundStyle(BrandColor.bean6)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.bordered)
                Spacer()
                Button(action: save) {
                    if saving {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Saving…")
                        }
                    } else {
                        Text("Save & Restart")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving || draftSubdomain.isEmpty || draftSubdomain == prefs.subdomain)
                .accessibilityIdentifier("editor.subdomainSave")
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(BrandColor.bean1)
        .onAppear { draftSubdomain = prefs.subdomain }
    }

    private func save() {
        saving = true
        error = nil

        Task {
            do {
                try await applySubdomainChange()
                await MainActor.run {
                    saving = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    self.saving = false
                    self.error = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func applySubdomainChange() async throws {
        guard let zoneID = prefs.selectedZoneID,
              let zoneName = prefs.selectedZoneName,
              let tunnelID = prefs.tunnelID else {
            throw EditorError.missingPrerequisite("Run the wizard first to configure account/zone/tunnel.")
        }

        let oldSub = prefs.subdomain
        prefs.subdomain = draftSubdomain

        let apiToken = try await KeychainService.shared.getAPIToken()
        guard let apiToken else {
            prefs.subdomain = oldSub
            throw EditorError.missingPrerequisite("No API token in Keychain.")
        }
        let client = CloudflareClient(token: apiToken)
        let newHost = "\(draftSubdomain).\(zoneName)"
        let target = "\(tunnelID).cfargotunnel.com"

        if let existing = try await client.findCNAME(zoneID: zoneID, name: newHost) {
            _ = try await client.updateCNAME(zoneID: zoneID, recordID: existing.id,
                                              name: newHost, target: target)
        } else {
            _ = try await client.createCNAME(zoneID: zoneID, name: newHost, target: target)
        }

        if let runToken = try await KeychainService.shared.getRunToken(tunnelID: tunnelID) {
            try await CloudflaredManager.shared.restart(runToken: runToken)
        }
    }
}

// MARK: - SSH username editor

struct SSHUsernameEditorPopover: View {

    var onDismiss: () -> Void

    private let prefs = PreferencesStore.shared

    @State private var draftUsername: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit SSH username")
                .font(BrandFont.title)
                .foregroundStyle(BrandColor.cream)

            TextField("username", text: $draftUsername)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .accessibilityIdentifier("editor.usernameField")

            Text("This only changes the Copy-SSH command on the Dashboard. It does not change which user account exists on this Mac.")
                .font(BrandFont.mono)
                .foregroundStyle(BrandColor.bean6)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save") {
                    prefs.sshUsername = draftUsername
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftUsername.isEmpty || draftUsername == prefs.sshUsername)
                .accessibilityIdentifier("editor.usernameSave")
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(BrandColor.bean1)
        .onAppear { draftUsername = prefs.sshUsername }
    }
}

// MARK: - Diagnostics sheet

struct DiagnosticsSheet: View {

    var onDismiss: () -> Void

    private let prefs = PreferencesStore.shared

    @State private var running: Bool = false
    @State private var result: SelfTestResult? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(BrandFont.title)
                .foregroundStyle(BrandColor.cream)

            if let host = prefs.fullyQualifiedHostname {
                Text("Probing \(host) from this machine over the public internet.")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.cream2)
            } else {
                Text("No hostname configured — finish the wizard first.")
                    .font(BrandFont.mono)
                    .foregroundStyle(BrandColor.magenta)
            }

            if running {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Running…")
                        .font(BrandFont.mono)
                        .foregroundStyle(BrandColor.cream)
                }
                .padding(8)
            }

            if let r = result {
                resultTable(r)
            }

            HStack {
                Button("Close", action: onDismiss)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Run Self-Test") {
                    runTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(running || prefs.fullyQualifiedHostname == nil)
                .accessibilityIdentifier("diagnostics.runButton")
            }
        }
        .padding(24)
        .frame(width: 480, height: 360)
        .background(BrandColor.bean1)
    }

    @ViewBuilder
    private func resultTable(_ r: SelfTestResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Verdict", r.passed ? "PASS" : "FAIL", color: r.passed ? BrandColor.acid : BrandColor.magenta)
            row("Hostname", r.hostname)
            row("DNS",  r.dnsOK ? "ok" : "FAIL")
            if let addr = r.dnsResolvedTo {
                row("Resolved to", addr)
            }
            row("HTTP code", "\(r.httpsCode)")
            row("Latency", "\(r.latencyMs) ms")
            if let e = r.error {
                row("Error", e, color: BrandColor.magenta)
            }
            Text(r.summary)
                .font(BrandFont.mono)
                .foregroundStyle(BrandColor.cream2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.bean2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func row(_ k: String, _ v: String, color: Color = BrandColor.cream) -> some View {
        HStack {
            Text(k)
                .font(BrandFont.label)
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(BrandColor.bean6)
                .frame(width: 110, alignment: .leading)
            Text(v)
                .font(BrandFont.mono)
                .foregroundStyle(color)
            Spacer()
        }
    }

    private func runTest() {
        guard let host = prefs.fullyQualifiedHostname else { return }
        running = true
        result = nil
        Task {
            let r = await SelfTest.runSelfTest(hostname: host)
            await MainActor.run {
                self.result = r
                self.running = false
            }
        }
    }
}

// MARK: - Errors

private enum EditorError: LocalizedError {
    case missingPrerequisite(String)

    var errorDescription: String? {
        switch self {
        case .missingPrerequisite(let m): return m
        }
    }
}
