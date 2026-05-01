// MetricsClient.swift
// Burrow — polls cloudflared's Prometheus metrics endpoint.
//
// cloudflared exposes a Prometheus text-format metrics endpoint at
// 127.0.0.1:20241/metrics by default. We poll every 5s while the tunnel
// is running and parse the keys we care about for the Dashboard card.
//
// Spec: UX-GAP-ANALYSIS §3 + Phase D-D.

import Foundation
import Observation
import OSLog

/// Snapshot of the most-recently-parsed cloudflared metrics.
/// All counters are Int — Prometheus emits floats but cloudflared's counters
/// are integral in practice; we cast.
@Observable
final class MetricsSnapshot {
    var activeStreams: Int = 0
    var totalRequests: Int = 0
    /// edge region (e.g. "ewr01") → connection count
    var edges: [String: Int] = [:]
    var bytesIn: Int = 0
    var bytesOut: Int = 0
    var lastError: String? = nil
    var lastUpdate: Date? = nil
}

@MainActor
@Observable
final class MetricsClient {

    static let shared = MetricsClient()

    let snapshot = MetricsSnapshot()

    private var pollTask: Task<Void, Never>? = nil
    private let url = URL(string: "http://127.0.0.1:20241/metrics")!
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 4
        cfg.timeoutIntervalForResource = 4
        return URLSession(configuration: cfg)
    }()

    private init() {}

    /// Begin polling at 5s intervals. Idempotent — calling start() while
    /// already polling is a no-op.
    func start() {
        guard pollTask == nil else { return }
        Log.network.info("MetricsClient polling started → \(self.url.absoluteString, privacy: .public)")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    /// Cancel polling. Safe to call multiple times.
    func stop() {
        pollTask?.cancel()
        pollTask = nil
        Log.network.info("MetricsClient polling stopped")
    }

    /// Reset the snapshot (e.g. after a restart so old counters don't linger).
    func reset() {
        snapshot.activeStreams = 0
        snapshot.totalRequests = 0
        snapshot.edges = [:]
        snapshot.bytesIn = 0
        snapshot.bytesOut = 0
        snapshot.lastError = nil
        snapshot.lastUpdate = nil
    }

    // MARK: - Internal

    private func pollOnce() async {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                snapshot.lastError = "metrics endpoint returned non-200"
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                snapshot.lastError = "metrics endpoint returned non-utf8"
                return
            }
            parse(text)
            snapshot.lastError = nil
            snapshot.lastUpdate = Date()
        } catch {
            // Connection refused is expected when cloudflared just started or just stopped.
            snapshot.lastError = "metrics unreachable"
        }
    }

    /// Parse Prometheus text-format. We only extract the series the Dashboard cares about.
    /// Format: `metric_name{label1="value",label2="value"} value`
    private func parse(_ text: String) {
        var totalRequests = 0
        var activeStreams = 0
        var edges: [String: Int] = [:]
        var bytesIn = 0
        var bytesOut = 0

        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2,
                  let value = Double(parts[1]) else { continue }
            let nameWithLabels = String(parts[0])

            let metricName: String
            let labels: String
            if let braceIdx = nameWithLabels.firstIndex(of: "{") {
                metricName = String(nameWithLabels[..<braceIdx])
                labels = String(nameWithLabels[braceIdx...])
            } else {
                metricName = nameWithLabels
                labels = ""
            }

            switch metricName {
            case "cloudflared_tunnel_active_streams":
                activeStreams += Int(value)
            case "cloudflared_tunnel_total_requests":
                totalRequests += Int(value)
            case "cloudflared_tunnel_response_by_code":
                totalRequests += Int(value)
            case "cloudflared_quic_connections", "cloudflared_tunnel_concurrent_requests_per_tunnel":
                if let region = extractLabel("connection_index", from: labels)
                    ?? extractLabel("location", from: labels)
                    ?? extractLabel("edge", from: labels) {
                    edges[region, default: 0] += Int(value)
                }
            case "cloudflared_tunnel_tcp_rx_bytes":
                bytesIn += Int(value)
            case "cloudflared_tunnel_tcp_tx_bytes":
                bytesOut += Int(value)
            default:
                continue
            }
        }

        snapshot.activeStreams = activeStreams
        snapshot.totalRequests = totalRequests
        snapshot.edges = edges
        snapshot.bytesIn = bytesIn
        snapshot.bytesOut = bytesOut
    }

    private func extractLabel(_ key: String, from labels: String) -> String? {
        guard let range = labels.range(of: "\(key)=\"") else { return nil }
        let after = labels[range.upperBound...]
        guard let endQuote = after.firstIndex(of: "\"") else { return nil }
        return String(after[..<endQuote])
    }
}
