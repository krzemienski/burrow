// TunnelTab.swift
// Burrow — Settings → Tunnel.
// PRP §FR-5.3.

import SwiftUI
import AppKit

struct TunnelTab: View {

    private let prefs = PreferencesStore.shared

    @State private var localPort: String = "22"
    @State private var portError: String? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var deleteError: String? = nil
    @State private var isDeleting: Bool = false
    @State private var copyIDConfirmed: Bool = false

    var body: some View {
        Form {
            Section("Tunnel Identity") {
                LabeledContent("Name") {
                    Text(prefs.tunnelName ?? "—")
                        .foregroundStyle(prefs.tunnelName == nil ? .secondary : .primary)
                        .textSelection(.enabled)
                }

                LabeledContent("Tunnel ID") {
                    HStack {
                        Text(prefs.tunnelID ?? "—")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(prefs.tunnelID == nil ? .secondary : .primary)
                            .textSelection(.enabled)
                        if let tid = prefs.tunnelID {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(tid, forType: .string)
                                copyIDConfirmed = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copyIDConfirmed = false
                                }
                            } label: {
                                Image(systemName: copyIDConfirmed ? "checkmark" : "doc.on.doc")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy tunnel ID")
                        }
                    }
                }
            }

            Section("SSH") {
                LabeledContent("Local port") {
                    HStack {
                        TextField("22", text: $localPort)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Local SSH port")
                            .onChange(of: localPort) { _, newValue in
                                validateAndSavePort(newValue)
                            }
                        Text("(1–65535)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let err = portError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Delete Tunnel…", role: .destructive) {
                    showDeleteConfirm = true
                }
                .accessibilityLabel("Delete tunnel and DNS record")
                .disabled(prefs.tunnelID == nil || isDeleting)

                if isDeleting {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Deleting tunnel…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let err = deleteError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            localPort = String(prefs.localPort)
        }
        .alert("Delete Tunnel?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteTunnel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the cloudflared process, delete the tunnel from Cloudflare, and remove the DNS record. This cannot be undone.")
        }
    }

    // MARK: - Validation

    private func validateAndSavePort(_ raw: String) {
        portError = nil
        guard let port = Int(raw), port >= 1, port <= 65535 else {
            portError = "Port must be 1–65535"
            return
        }
        prefs.localPort = port
    }

    // MARK: - Delete

    private func deleteTunnel() {
        guard let accountID = prefs.selectedAccountID,
              let tunnelID = prefs.tunnelID else { return }
        isDeleting = true
        deleteError = nil

        Task {
            do {
                // Stop cloudflared first
                await CloudflaredManager.shared.stop()
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10s wait

                // Delete DNS record if we have the zone
                if let zoneID = prefs.selectedZoneID,
                   let fqdn = prefs.fullyQualifiedHostname {
                    let token = try await KeychainService.shared.getAPIToken()
                    if let t = token {
                        let client = CloudflareClient(auth: CloudflareAuth.resolved(token: t))
                        if let record = try await client.findCNAME(zoneID: zoneID, name: fqdn) {
                            try await client.deleteDNSRecord(zoneID: zoneID, recordID: record.id)
                        }
                        // Delete the tunnel
                        try await client.deleteTunnel(accountID: accountID, tunnelID: tunnelID)
                    }
                }

                // Clean up keychain run token
                try? await KeychainService.shared.deleteRunToken(tunnelID: tunnelID)

                // Clear stored tunnel data
                await MainActor.run {
                    prefs.tunnelID = nil
                    prefs.tunnelName = nil
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                    isDeleting = false
                }
            }
        }
    }
}
