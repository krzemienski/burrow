// CreateTunnelStep.swift  — Phase 6
// Progress steps:
//   a. Creating tunnel…           (POST /cfd_tunnel)
//   b. Storing run token…         (Keychain)
//   c. Pushing ingress config…    (PUT /configurations)
//   d. Creating DNS record…       (POST /dns_records)
//   e. Launching cloudflared…     (Process.run)
//   f. Verifying connection…      (wait for state .running, max 15s)

import SwiftUI

struct CreateTunnelStep: View {

    let auth: CloudflareAuth
    let account: Account
    let zone: Zone
    let subdomain: String
    var onComplete: () -> Void

    @State private var steps: [StepItem] = StepItem.all
    @State private var overallError: String? = nil
    @State private var isRunning: Bool = false

    struct StepItem: Identifiable {
        let id: Int
        let label: String
        var status: Status = .pending

        enum Status { case pending, running, done, failed }

        static let all: [StepItem] = [
            StepItem(id: 0, label: "Creating tunnel…"),
            StepItem(id: 1, label: "Storing run token in Keychain…"),
            StepItem(id: 2, label: "Pushing ingress config…"),
            StepItem(id: 3, label: "Creating DNS record…"),
            StepItem(id: 4, label: "Launching cloudflared…"),
            StepItem(id: 5, label: "Verifying connection…")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Setting Up Your Tunnel")
                .font(.title2.weight(.semibold))

            Text("Burrow is creating and configuring your Cloudflare tunnel. This takes about 10–20 seconds.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(steps) { step in
                    HStack(spacing: 10) {
                        stepIcon(step.status)
                            .frame(width: 20)
                        Text(step.label)
                            .foregroundStyle(stepTextColor(step.status))
                    }
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let err = overallError {
                Label(err, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)

                Button("Retry") {
                    overallError = nil
                    steps = StepItem.all
                    run()
                }
                .accessibilityLabel("Retry tunnel creation")
            }

            Spacer()
        }
        .padding(32)
        .onAppear {
            if !isRunning { run() }
        }
    }

    @ViewBuilder
    private func stepIcon(_ status: StepItem.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func stepTextColor(_ status: StepItem.Status) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .primary
        case .done:    return .primary
        case .failed:  return .red
        }
    }

    // MARK: - Execution

    private func run() {
        isRunning = true
        let fqdn = "\(subdomain).\(zone.name)"
        let tunnelName = "burrow-\(subdomain)"
        let localPort = PreferencesStore.shared.localPort

        Task {
            let client = CloudflareClient(auth: auth)
            do {
                // Step a: create tunnel
                await setStep(0, .running)
                let tunnel = try await client.createTunnel(accountID: account.id, name: tunnelName)
                await setStep(0, .done)

                // Step b: store run token
                await setStep(1, .running)
                let runToken = try await client.getTunnelRunToken(accountID: account.id, tunnelID: tunnel.id)
                try await KeychainService.shared.setRunToken(runToken, tunnelID: tunnel.id)
                await setStep(1, .done)

                // Step c: push ingress config
                await setStep(2, .running)
                try await client.setIngressConfig(accountID: account.id,
                                                   tunnelID: tunnel.id,
                                                   hostname: fqdn,
                                                   localPort: localPort)
                await setStep(2, .done)

                // Step d: create/upsert DNS record
                await setStep(3, .running)
                let target = "\(tunnel.id).cfargotunnel.com"
                if let existing = try await client.findCNAME(zoneID: zone.id, name: fqdn) {
                    _ = try await client.updateCNAME(zoneID: zone.id, recordID: existing.id,
                                                     name: fqdn, target: target)
                } else {
                    _ = try await client.createCNAME(zoneID: zone.id, name: fqdn, target: target)
                }
                await setStep(3, .done)

                // Persist tunnel metadata to prefs
                await MainActor.run {
                    let p = PreferencesStore.shared
                    p.tunnelID   = tunnel.id
                    p.tunnelName = tunnel.name
                    p.selectedAccountID = account.id
                    p.selectedZoneID    = zone.id
                    p.selectedZoneName  = zone.name
                    p.subdomain         = subdomain
                }

                // Step e: launch cloudflared
                await setStep(4, .running)
                try await CloudflaredManager.shared.start(runToken: runToken)
                await setStep(4, .done)

                // Step f: wait for .running state (max 15s)
                await setStep(5, .running)
                let deadline = ContinuousClock.now.advanced(by: .seconds(15))
                var verified = false
                while ContinuousClock.now < deadline {
                    let s = await CloudflaredManager.shared.state
                    if case .running = s {
                        verified = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
                await setStep(5, verified ? .done : .failed)

                if verified {
                    await MainActor.run { onComplete() }
                } else {
                    await MainActor.run {
                        overallError = "Tunnel did not connect within 15s. Check your token and cloudflared."
                    }
                }

            } catch {
                // Mark the currently-running step as failed
                await markCurrentFailed()
                await MainActor.run {
                    overallError = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }

    @MainActor
    private func setStep(_ id: Int, _ status: StepItem.Status) {
        guard id < steps.count else { return }
        steps[id].status = status
    }

    @MainActor
    private func markCurrentFailed() {
        for i in steps.indices {
            if steps[i].status == .running {
                steps[i].status = .failed
            }
        }
    }
}
