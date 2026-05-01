// WizardCoordinator.swift
// Burrow — drives the 7-step first-run wizard.
//
// Phase 6 deliverable. PRP §FR-1 + §4 Phase 6.

import SwiftUI
import Observation

@Observable
final class WizardCoordinator {

    enum Step: Int, CaseIterable {
        case welcome
        case token
        case accountAndZone
        case subdomain
        case cloudflaredCheck
        case createTunnel
        case done
    }

    var current: Step = .welcome

    // Accumulated configuration (committed only at .done)
    var token: String = ""
    var selectedAccount: Account?
    var selectedZone: Zone?
    var subdomain: String = "m4"
    var cloudflaredPath: URL?

    func next() {
        guard let next = Step(rawValue: current.rawValue + 1) else { return }
        current = next
    }

    func back() {
        guard let prev = Step(rawValue: current.rawValue - 1) else { return }
        current = prev
    }
}

// MARK: - Coordinator view

struct WizardCoordinatorView: View {

    @State private var coordinator = WizardCoordinator()
    var onDismiss: () -> Void

    var body: some View {
        Group {
            switch coordinator.current {
            case .welcome:
                WelcomeStep {
                    coordinator.next()
                }

            case .token:
                TokenStep(token: $coordinator.token) {
                    coordinator.next()
                }

            case .accountAndZone:
                AccountZoneStep(
                    token: coordinator.token,
                    selectedAccount: $coordinator.selectedAccount,
                    selectedZone: $coordinator.selectedZone
                ) {
                    coordinator.next()
                }

            case .subdomain:
                SubdomainStep(
                    subdomain: $coordinator.subdomain,
                    zone: coordinator.selectedZone
                ) {
                    coordinator.next()
                }

            case .cloudflaredCheck:
                CloudflaredCheckStep(
                    onFound: { url in
                        coordinator.cloudflaredPath = url
                    },
                    onContinue: {
                        coordinator.next()
                    }
                )

            case .createTunnel:
                if let account = coordinator.selectedAccount,
                   let zone = coordinator.selectedZone {
                    CreateTunnelStep(
                        token: coordinator.token,
                        account: account,
                        zone: zone,
                        subdomain: coordinator.subdomain
                    ) {
                        coordinator.next()
                    }
                } else {
                    // Shouldn't happen if prior steps gate correctly
                    Text("Missing account or zone selection.")
                        .foregroundStyle(.secondary)
                        .padding()
                }

            case .done:
                DoneStep {
                    // D-H: persist token + dismiss wizard + open Dashboard + auto-start tunnel
                    Task { @MainActor in
                        try? await KeychainService.shared.setAPIToken(coordinator.token)

                        // Open Dashboard (via AppDelegate's bridge)
                        NotificationCenter.default.post(
                            name: .burrowRequestOpenWindow,
                            object: nil,
                            userInfo: ["id": "dashboard"]
                        )

                        // Auto-start the tunnel so Dashboard shows STARTING → RUNNING
                        if let tunnelID = PreferencesStore.shared.tunnelID,
                           let runToken = try? await KeychainService.shared.getRunToken(tunnelID: tunnelID) {
                            try? await CloudflaredManager.shared.start(runToken: runToken)

                            if let host = PreferencesStore.shared.fullyQualifiedHostname {
                                Notifier.shared.fire(.firstSuccess(
                                    hostname: host,
                                    sshUser: PreferencesStore.shared.sshUsername
                                ))
                            }
                        }

                        onDismiss()
                    }
                }
            }
        }
        .frame(width: 560, height: 420)
        .animation(.easeInOut(duration: 0.2), value: coordinator.current)
    }
}
