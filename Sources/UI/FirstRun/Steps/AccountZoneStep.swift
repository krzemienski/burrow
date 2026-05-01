// AccountZoneStep.swift  — Phase 6
// Pickers populated from CloudflareClient.listAccounts + listZones.
// Auto-selects when there is exactly one of each.

import SwiftUI

struct AccountZoneStep: View {

    let auth: CloudflareAuth
    @Binding var selectedAccount: Account?
    @Binding var selectedZone: Zone?
    var onContinue: () -> Void

    @State private var accounts: [Account] = []
    @State private var zones: [Zone] = []
    @State private var loadState: LoadState = .loading
    @State private var selectedAccountID: String = ""
    @State private var selectedZoneID: String = ""

    enum LoadState {
        case loading
        case loaded
        case error(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Account & Zone")
                .font(.title2.weight(.semibold))

            Text("Select the Cloudflare account and DNS zone where Burrow will create the tunnel.")
                .foregroundStyle(.secondary)

            switch loadState {
            case .loading:
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading your accounts and zones…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)

            case .error(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Button("Retry") { load() }
                    .accessibilityLabel("Retry loading accounts and zones")

            case .loaded:
                Form {
                    Picker("Account", selection: $selectedAccountID) {
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }
                    .accessibilityLabel("Cloudflare account")
                    .onChange(of: selectedAccountID) { _, newID in
                        selectedAccount = accounts.first { $0.id == newID }
                    }

                    let filteredZones = zones.filter {
                        $0.account?.id == selectedAccountID || selectedAccountID.isEmpty
                    }

                    Picker("Zone", selection: $selectedZoneID) {
                        ForEach(filteredZones) { zone in
                            Text(zone.name).tag(zone.id)
                        }
                    }
                    .accessibilityLabel("DNS zone")
                    .onChange(of: selectedZoneID) { _, newID in
                        selectedZone = zones.first { $0.id == newID }
                    }
                }
                .formStyle(.grouped)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedAccount == nil || selectedZone == nil)
                .accessibilityLabel("Continue to subdomain step")
                .keyboardShortcut(.return)
            }
        }
        .padding(32)
        .onAppear { load() }
    }

    // MARK: - Load

    private func load() {
        loadState = .loading
        Task {
            do {
                let client = CloudflareClient(auth: auth)
                async let accts = client.listAccounts()
                async let zns   = client.listZones()
                let (a, z) = try await (accts, zns)
                await MainActor.run {
                    // DEF-2 fix (PRD §11.1 AT-3): empty results with HTTP 200
                    // means the token is active but lacks read scopes. Surface
                    // the missing-scope guidance instead of silently advancing
                    // to a step with empty pickers.
                    if a.isEmpty && z.isEmpty {
                        loadState = .error(
                            "Token is missing required read scopes.\n\n" +
                            "Add at least these to the token at " +
                            "dash.cloudflare.com/profile/api-tokens:\n" +
                            "  • Account → Account Settings → Read\n" +
                            "  • Zone → Zone → Read"
                        )
                        return
                    }
                    if a.isEmpty {
                        loadState = .error(
                            "Token cannot read any accounts.\n" +
                            "Add: Account → Account Settings → Read"
                        )
                        return
                    }
                    if z.isEmpty {
                        loadState = .error(
                            "Token cannot read any zones.\n" +
                            "Add: Zone → Zone → Read"
                        )
                        return
                    }
                    accounts = a
                    zones    = z
                    // Auto-select if only one option
                    if selectedAccountID.isEmpty {
                        selectedAccountID = a.first?.id ?? ""
                        selectedAccount   = a.first
                    }
                    let filtered = z.filter { $0.account?.id == selectedAccountID }
                    if selectedZoneID.isEmpty {
                        let first = filtered.first ?? z.first
                        selectedZoneID = first?.id ?? ""
                        selectedZone   = first
                    }
                    loadState = .loaded
                }
            } catch {
                await MainActor.run {
                    loadState = .error(error.localizedDescription)
                }
            }
        }
    }
}
