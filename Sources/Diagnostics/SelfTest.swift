// SelfTest.swift
// Burrow — "Test from outside" diagnostics for the Dashboard.
//
// Resolves DNS for the configured hostname, then issues an HTTPS GET
// (10 s timeout) to confirm the tunnel + Cloudflare edge actually answer.
// All probes are real network calls — no mocking, no canned responses.
//
// Spec: UX-GAP §3 + Phase D-J.

import Foundation
import Network

struct SelfTestResult {
    let hostname: String
    let dnsOK: Bool
    let dnsResolvedTo: String?
    /// HTTP status returned by the GET (zero if request failed entirely).
    let httpsCode: Int
    /// Round-trip in milliseconds (zero if request failed before getting a response).
    let latencyMs: Int
    let error: String?
    let timestamp: Date

    var passed: Bool {
        // The Cloudflare Access challenge returns 401/403 because we're not signed
        // in — that still proves the edge + tunnel are wired up correctly.
        // 200/301/302/401/403 → tunnel works; anything else → fail.
        dnsOK && [200, 301, 302, 401, 403].contains(httpsCode)
    }

    var summary: String {
        if passed {
            return "PASS — tunnel reachable from internet (HTTP \(httpsCode), \(latencyMs)ms)"
        }
        if !dnsOK {
            return "FAIL — DNS for \(hostname) did not resolve"
        }
        if httpsCode == 0 {
            return "FAIL — HTTPS request failed: \(error ?? "unknown")"
        }
        return "FAIL — HTTP \(httpsCode) (\(latencyMs)ms): \(error ?? "unexpected status")"
    }
}

enum SelfTest {

    /// Run the full self-test against `hostname`. Always async; never throws.
    /// Returns a fully-populated SelfTestResult that the Dashboard renders verbatim.
    static func runSelfTest(hostname: String) async -> SelfTestResult {
        let started = Date()
        let dns = await resolveDNS(hostname: hostname)

        guard dns.ok else {
            return SelfTestResult(
                hostname: hostname,
                dnsOK: false,
                dnsResolvedTo: nil,
                httpsCode: 0,
                latencyMs: 0,
                error: "DNS resolution failed",
                timestamp: started
            )
        }

        guard let url = URL(string: "https://\(hostname)/") else {
            return SelfTestResult(
                hostname: hostname,
                dnsOK: true,
                dnsResolvedTo: dns.address,
                httpsCode: 0,
                latencyMs: 0,
                error: "invalid URL",
                timestamp: started
            )
        }

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 10
        let session = URLSession(configuration: cfg)

        let httpStart = Date()
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Burrow/1.0 (self-test)", forHTTPHeaderField: "User-Agent")
            let (_, response) = try await session.data(for: req)
            let elapsed = Int(Date().timeIntervalSince(httpStart) * 1000)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return SelfTestResult(
                hostname: hostname,
                dnsOK: true,
                dnsResolvedTo: dns.address,
                httpsCode: code,
                latencyMs: elapsed,
                error: nil,
                timestamp: started
            )
        } catch {
            return SelfTestResult(
                hostname: hostname,
                dnsOK: true,
                dnsResolvedTo: dns.address,
                httpsCode: 0,
                latencyMs: Int(Date().timeIntervalSince(httpStart) * 1000),
                error: error.localizedDescription,
                timestamp: started
            )
        }
    }

    // MARK: - DNS resolution helper

    private static func resolveDNS(hostname: String) async -> (ok: Bool, address: String?) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, String?), Never>) in
            let host = NWEndpoint.Host(hostname)
            let port = NWEndpoint.Port(integerLiteral: 443)
            let conn = NWConnection(host: host, port: port, using: .tls)
            var didResume = false
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !didResume {
                        didResume = true
                        let addr: String?
                        if let endpoint = conn.currentPath?.remoteEndpoint {
                            addr = "\(endpoint)"
                        } else {
                            addr = nil
                        }
                        conn.cancel()
                        continuation.resume(returning: (true, addr))
                    }
                case .failed:
                    if !didResume {
                        didResume = true
                        conn.cancel()
                        continuation.resume(returning: (false, nil))
                    }
                default:
                    break
                }
            }
            conn.start(queue: .global())
            // 5-second DNS timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if !didResume {
                    didResume = true
                    conn.cancel()
                    continuation.resume(returning: (false, nil))
                }
            }
        }
    }
}
