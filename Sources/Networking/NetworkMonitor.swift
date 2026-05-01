// NetworkMonitor.swift
// Burrow — wraps NWPathMonitor.
//
// Phase 7 deliverable. The closure-based API in PRP §5.4 is the
// canonical pattern.
//
// D-G addition: SSID via CWWiFiClient + isLocalSSHListening probe via NWConnection.

import Foundation
import Network
import CoreWLAN
import Observation
import OSLog

@Observable
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.krzemienski.burrow.network")

    private(set) var isSatisfied: Bool = false

    /// Current Wi-Fi SSID, if connected to one. nil when offline or on Ethernet.
    /// Polled every 10 s while online (D-G).
    private(set) var currentSSID: String?

    /// True if something is listening on localhost:22. Polled every 10 s while online.
    /// Surface in the Dashboard so the user knows their Mac will accept the tunneled SSH.
    private(set) var isLocalSSHListening: Bool = false

    /// Fired whenever the path satisfaction changes. Callers use the
    /// transition into `.satisfied` to schedule a tunnel reconnect
    /// (with the 2 s debounce required by PRP §FR-6.1).
    var onTransition: ((Bool) -> Void)?

    private var pollTimer: Timer?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            DispatchQueue.main.async {
                guard satisfied != self.isSatisfied else { return }
                self.isSatisfied = satisfied
                self.onTransition?(satisfied)
                if satisfied { self.startPolling() } else { self.stopPolling() }
            }
        }
        monitor.start(queue: queue)
        DispatchQueue.main.async { [weak self] in self?.startPolling() }
    }

    deinit {
        // PRP §3.6 gotcha #4: cancel from the same queue.
        monitor.cancel()
        pollTimer?.invalidate()
    }

    // MARK: - D-G periodic probes

    private func startPolling() {
        guard pollTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshSSID()
            self?.probeLocalSSH()
        }
        pollTimer = t
        refreshSSID()
        probeLocalSSH()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Read the Wi-Fi SSID via CoreWLAN. Returns nil when on Ethernet,
    /// when location services have not granted SSID access, or when
    /// the radio is off. PRP §3.6.X: handle nil gracefully — never crash,
    /// just hide the field.
    private func refreshSSID() {
        let ssid = CWWiFiClient.shared().interface()?.ssid()
        DispatchQueue.main.async { [weak self] in
            self?.currentSSID = ssid
        }
    }

    /// Quick NWConnection probe to localhost:22. We accept either .ready
    /// (something listening) or .failed/.cancelled (nothing). 1 s budget.
    private func probeLocalSSH() {
        let port = NWEndpoint.Port(integerLiteral: 22)
        let conn = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        var didResolve = false
        let resolve: (Bool) -> Void = { [weak self] listening in
            guard !didResolve else { return }
            didResolve = true
            conn.cancel()
            DispatchQueue.main.async {
                self?.isLocalSSHListening = listening
            }
        }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:                resolve(true)
            case .failed, .cancelled:   resolve(false)
            default: break
            }
        }
        conn.start(queue: queue)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            resolve(false)
        }
    }
}
