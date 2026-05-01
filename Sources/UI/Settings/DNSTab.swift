// DNSTab.swift
// Burrow — Settings → DNS.
// PRP §FR-5.4.

import SwiftUI

struct DNSTab: View {

    private let prefs = PreferencesStore.shared

    @State private var subdomain: String = ""
    @State private var applyStatus: ApplyStatus = .idle
    @State private var debounceTask: Task<Void, Never>? = nil

    enum ApplyStatus {
        case idle
        case applying
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Subdomain") {
                TextField("e.g. m4", text: $subdomain)
                    .accessibilityLabel("Subdomain for your tunnel hostname")
                    .onChange(of: subdomain) { _, newValue in
                        scheduleDebounced(newValue)
                    }

                LabeledContent("FQDN preview") {
                    if let fqdn = computedFQDN {
                        Text(fqdn)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Apply DNS Changes") {
                    applyDNS()
                }
                .accessibilityLabel("Apply DNS changes to Cloudflare")
                .disabled(!canApply)

                applyStatusView
            }
        }
        .formStyle(.grouped)
        .onAppear {
            subdomain = prefs.subdomain
        }
    }

    // MARK: - Computed

    private var computedFQDN: String? {
        guard !subdomain.isEmpty, let zone = prefs.selectedZoneName else { return nil }
        return "\(subdomain).\(zone)"
    }

    private var canApply: Bool {
        if case .applying = applyStatus { return false }
        return computedFQDN != nil && prefs.tunnelID != nil
    }

    @ViewBuilder
    private var applyStatusView: some View {
        switch applyStatus {
        case .idle:
            EmptyView()
        case .applying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Applying DNS changes…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success(let fqdn):
            Label("CNAME set for \(fqdn)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Actions

    private func scheduleDebounced(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard !Task.isCancelled else { return }
            await MainActor.run {
                prefs.subdomain = newValue
            }
        }
    }

    private func applyDNS() {
        guard let fqdn = computedFQDN,
              let zoneID = prefs.selectedZoneID,
              let tunnelID = prefs.tunnelID else { return }

        applyStatus = .applying

        Task {
            do {
                guard let rawToken = try await KeychainService.shared.getAPIToken() else {
                    await MainActor.run {
                        applyStatus = .failure("No API token stored. Set it in the Cloudflare tab.")
                    }
                    return
                }
                let client = CloudflareClient(auth: CloudflareAuth.resolved(token: rawToken))
                let target = "\(tunnelID).cfargotunnel.com"

                if let existing = try await client.findCNAME(zoneID: zoneID, name: fqdn) {
                    _ = try await client.updateCNAME(zoneID: zoneID,
                                                     recordID: existing.id,
                                                     name: fqdn,
                                                     target: target)
                } else {
                    _ = try await client.createCNAME(zoneID: zoneID,
                                                     name: fqdn,
                                                     target: target)
                }
                await MainActor.run {
                    applyStatus = .success(fqdn)
                }
            } catch {
                await MainActor.run {
                    applyStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}
