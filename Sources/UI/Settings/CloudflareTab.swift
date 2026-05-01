// CloudflareTab.swift
// Burrow — Settings → Cloudflare.
// PRP §FR-5.2.

import SwiftUI

struct CloudflareTab: View {

    private let prefs = PreferencesStore.shared

    @State private var tokenInput: String = ""
    @State private var verifyState: VerifyState = .idle
    @State private var accounts: [Account] = []
    @State private var zones: [Zone] = []
    @State private var selectedAccountID: String = ""
    @State private var selectedZoneID: String = ""
    @State private var loadError: String? = nil
    @State private var saveConfirmed: Bool = false

    enum VerifyState {
        case idle
        case checking
        case valid(id: String)
        case invalid(reason: String)
        case scopeError(missing: [String])
    }

    var body: some View {
        Form {
            Section("API Token") {
                SecureField("Paste your Cloudflare API token", text: $tokenInput)
                    .accessibilityLabel("Cloudflare API token input")

                HStack {
                    Button("Verify") {
                        verify()
                    }
                    .accessibilityLabel("Verify API token")
                    .disabled(tokenInput.isEmpty || isVerifying)

                    verifyStatusView
                }
            }

            if case .valid = verifyState {
                Section("Account") {
                    if accounts.isEmpty {
                        ProgressView("Loading accounts…")
                            .onAppear { loadAccounts() }
                    } else {
                        Picker("Account", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text(account.name).tag(account.id)
                            }
                        }
                        .accessibilityLabel("Cloudflare account picker")
                        .onChange(of: selectedAccountID) { _, newID in
                            prefs.selectedAccountID = newID
                            filterZones(for: newID)
                        }
                    }
                }

                Section("Zone") {
                    let filtered = filteredZones
                    if filtered.isEmpty && !zones.isEmpty {
                        Text("No zones found for this account.")
                            .foregroundStyle(.secondary)
                    } else if filtered.isEmpty {
                        ProgressView("Loading zones…")
                            .onAppear { loadZones() }
                    } else {
                        Picker("Zone", selection: $selectedZoneID) {
                            ForEach(filtered) { zone in
                                Text(zone.name).tag(zone.id)
                            }
                        }
                        .accessibilityLabel("Cloudflare zone picker")
                        .onChange(of: selectedZoneID) { _, newID in
                            if let zone = zones.first(where: { $0.id == newID }) {
                                prefs.selectedZoneID = newID
                                prefs.selectedZoneName = zone.name
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Button("Save") {
                            saveToken()
                        }
                        .accessibilityLabel("Save Cloudflare credentials")

                        if saveConfirmed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            if case .scopeError(let missing) = verifyState {
                Section("Missing Scopes") {
                    ForEach(missing, id: \.self) { scope in
                        Label(scope, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    Text("Add these scopes to your token at dash.cloudflare.com/profile/api-tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = loadError {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadStoredState() }
    }

    // MARK: - Computed

    private var isVerifying: Bool {
        if case .checking = verifyState { return true }
        return false
    }

    private var filteredZones: [Zone] {
        guard !selectedAccountID.isEmpty else { return zones }
        return zones.filter { $0.account?.id == selectedAccountID }
    }

    @ViewBuilder
    private var verifyStatusView: some View {
        switch verifyState {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Token valid")
        case .invalid(let reason):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Token invalid: \(reason)")
        case .scopeError:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .accessibilityLabel("Token missing required scopes")
        }
    }

    // MARK: - Actions

    private func loadStoredState() {
        selectedAccountID = prefs.selectedAccountID ?? ""
        selectedZoneID    = prefs.selectedZoneID ?? ""
        Task {
            tokenInput = (try? await KeychainService.shared.getAPIToken()) ?? ""
        }
    }

    private func verify() {
        guard !tokenInput.isEmpty else { return }
        verifyState = .checking
        loadError = nil
        Task {
            do {
                let client = CloudflareClient(auth: CloudflareAuth.resolved(token: tokenInput))
                let result = try await client.verifyToken()
                if result.status == "active" {
                    await MainActor.run { verifyState = .valid(id: result.id) }
                    loadAccounts(client: client)
                    loadZones(client: client)
                } else {
                    await MainActor.run {
                        verifyState = .invalid(reason: "status: \(result.status)")
                    }
                }
            } catch CloudflareError.invalidToken {
                await MainActor.run { verifyState = .invalid(reason: "invalid token") }
            } catch CloudflareError.insufficientScope(let missing) {
                await MainActor.run { verifyState = .scopeError(missing: missing) }
            } catch {
                await MainActor.run { verifyState = .invalid(reason: error.localizedDescription) }
            }
        }
    }

    private func loadAccounts(client: CloudflareClient? = nil) {
        Task {
            do {
                let c = client ?? CloudflareClient(auth: CloudflareAuth.resolved(token: tokenInput))
                let result = try await c.listAccounts()
                await MainActor.run {
                    accounts = result
                    if selectedAccountID.isEmpty, let first = result.first {
                        selectedAccountID = first.id
                        prefs.selectedAccountID = first.id
                    }
                }
            } catch {
                await MainActor.run { loadError = "Accounts: \(error.localizedDescription)" }
            }
        }
    }

    private func loadZones(client: CloudflareClient? = nil) {
        Task {
            do {
                let c = client ?? CloudflareClient(auth: CloudflareAuth.resolved(token: tokenInput))
                let result = try await c.listZones()
                await MainActor.run {
                    zones = result
                    filterZones(for: selectedAccountID)
                }
            } catch {
                await MainActor.run { loadError = "Zones: \(error.localizedDescription)" }
            }
        }
    }

    private func filterZones(for accountID: String) {
        let filtered = filteredZones
        if selectedZoneID.isEmpty || !filtered.contains(where: { $0.id == selectedZoneID }) {
            if let first = filtered.first {
                selectedZoneID = first.id
                prefs.selectedZoneID = first.id
                prefs.selectedZoneName = first.name
            }
        }
    }

    private func saveToken() {
        Task {
            do {
                try await KeychainService.shared.setAPIToken(tokenInput)
                await MainActor.run {
                    saveConfirmed = true
                }
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { saveConfirmed = false }
            } catch {
                await MainActor.run {
                    loadError = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
