// CloudflareClient.swift
// Burrow — actor wrapping a single URLSession for all CF API v4 calls.
//
// PRP §3.3 enumerates the 11 endpoints this actor implements.

import Foundation
import OSLog

/// How CloudflareClient authenticates. Production wizard only ever uses
/// `.bearer` (scoped tokens). `.legacy` exists so dev/smoke validation
/// can drive the same actor with the user's existing Global API Key.
enum CloudflareAuth: Sendable {
    case bearer(token: String)
    case legacy(email: String, apiKey: String)
}

actor CloudflareClient {

    // MARK: - Configuration

    static let baseURL = URL(string: "https://api.cloudflare.com/client/v4")!

    private let session: URLSession
    private var auth: CloudflareAuth
    private let logger = Logger(subsystem: "com.krzemienski.burrow", category: "cloudflare")

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Init

    init(auth: CloudflareAuth) {
        // PRP §8 NFR-P4 — single URLSession reused for the app lifetime.
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.auth = auth
    }

    /// Convenience: Bearer-token init (preserves Phase 1 scaffold contract).
    init(token: String) {
        self.init(auth: .bearer(token: token))
    }

    /// Rotate the auth in place. Used by Settings → Cloudflare → Re-enter.
    func updateAuth(_ newAuth: CloudflareAuth) {
        self.auth = newAuth
    }

    /// Bearer-only convenience for callers that only know about scoped tokens.
    func updateToken(_ newToken: String) {
        self.auth = .bearer(token: newToken)
    }

    // MARK: - Endpoint surface

    // ---- 3.3.1 Token verification -----------------------------------------
    /// Bearer mode hits the canonical `/user/tokens/verify` endpoint.
    /// Legacy mode (Global API Key) cannot use that endpoint; hit `/user`
    /// and synthesize a TokenVerify with `status="active"` if the request
    /// succeeds (auth proven by the 200).
    func verifyToken() async throws -> TokenVerify {
        switch auth {
        case .bearer:
            let req = try makeRequest(method: "GET", path: Endpoint.tokensVerify())
            return try await execute(req, decode: TokenVerify.self)
        case .legacy:
            struct UserMin: Decodable { let id: String }
            let req = try makeRequest(method: "GET", path: "user")
            let user = try await execute(req, decode: UserMin.self)
            return TokenVerify(id: user.id, status: "active")
        }
    }

    // ---- 3.3.2 Account discovery ------------------------------------------
    func listAccounts() async throws -> [Account] {
        let req = try makeRequest(method: "GET", path: Endpoint.accounts())
        return try await execute(req, decode: [Account].self)
    }

    // ---- 3.3.3 Zone discovery ---------------------------------------------
    func listZones() async throws -> [Zone] {
        let req = try makeRequest(method: "GET", path: Endpoint.zones())
        return try await execute(req, decode: [Zone].self)
    }

    // ---- 3.3.4 Create named tunnel ----------------------------------------
    func createTunnel(accountID: String, name: String) async throws -> Tunnel {
        struct Body: Encodable {
            let name: String
            let configSrc: String
        }
        let body = Body(name: name, configSrc: "cloudflare")
        let req = try makeRequest(method: "POST",
                                  path: Endpoint.cfdTunnel(accountID: accountID),
                                  body: body)
        return try await execute(req, decode: Tunnel.self)
    }

    // ---- 3.3.5 Get tunnel run token ---------------------------------------
    func getTunnelRunToken(accountID: String, tunnelID: String) async throws -> String {
        let req = try makeRequest(method: "GET",
                                  path: Endpoint.cfdTunnelToken(accountID: accountID,
                                                                 tunnelID: tunnelID))
        return try await execute(req, decode: String.self)
    }

    // ---- 3.3.6 Set ingress configuration ----------------------------------
    func setIngressConfig(accountID: String, tunnelID: String, hostname: String, localPort: Int) async throws {
        struct IngressRule: Encodable {
            var hostname: String?
            let service: String
        }
        struct Config: Encodable {
            let ingress: [IngressRule]
        }
        struct Body: Encodable {
            let config: Config
        }

        let rules: [IngressRule] = [
            IngressRule(hostname: hostname, service: "ssh://localhost:\(localPort)"),
            IngressRule(hostname: nil, service: "http_status:404")
        ]
        let body = Body(config: Config(ingress: rules))
        let req = try makeRequest(method: "PUT",
                                  path: Endpoint.cfdTunnelConfigurations(accountID: accountID,
                                                                          tunnelID: tunnelID),
                                  body: body)
        // Result shape varies; we only care that success == true.
        struct AnyResult: Decodable {}
        _ = try await execute(req, decode: AnyResult.self)
    }

    // ---- 3.3.7 List tunnels -----------------------------------------------
    func listTunnels(accountID: String) async throws -> [Tunnel] {
        let path = Endpoint.cfdTunnel(accountID: accountID) + "?is_deleted=false"
        let req = try makeRequest(method: "GET", path: path)
        return try await execute(req, decode: [Tunnel].self)
    }

    // ---- 3.3.8 Delete tunnel ----------------------------------------------
    func deleteTunnel(accountID: String, tunnelID: String) async throws {
        let req = try makeRequest(method: "DELETE",
                                  path: Endpoint.cfdTunnel(accountID: accountID,
                                                            tunnelID: tunnelID))
        struct AnyResult: Decodable {}
        _ = try await execute(req, decode: AnyResult.self)
    }

    // ---- 3.3.9 DNS record CRUD --------------------------------------------
    func findCNAME(zoneID: String, name: String) async throws -> DNSRecord? {
        let path = Endpoint.dnsRecords(zoneID: zoneID) + "?name=\(name)&type=CNAME"
        let req = try makeRequest(method: "GET", path: path)
        let records = try await execute(req, decode: [DNSRecord].self)
        return records.first
    }

    func createCNAME(zoneID: String, name: String, target: String) async throws -> DNSRecord {
        struct Body: Encodable {
            let type: String
            let name: String
            let content: String
            let proxied: Bool
            let ttl: Int
        }
        let body = Body(type: "CNAME", name: name, content: target, proxied: true, ttl: 1)
        let req = try makeRequest(method: "POST",
                                  path: Endpoint.dnsRecords(zoneID: zoneID),
                                  body: body)
        return try await execute(req, decode: DNSRecord.self)
    }

    func updateCNAME(zoneID: String, recordID: String, name: String, target: String) async throws -> DNSRecord {
        struct Body: Encodable {
            let type: String
            let name: String
            let content: String
            let proxied: Bool
            let ttl: Int
        }
        let body = Body(type: "CNAME", name: name, content: target, proxied: true, ttl: 1)
        let req = try makeRequest(method: "PUT",
                                  path: Endpoint.dnsRecord(zoneID: zoneID, recordID: recordID),
                                  body: body)
        return try await execute(req, decode: DNSRecord.self)
    }

    func deleteDNSRecord(zoneID: String, recordID: String) async throws {
        let req = try makeRequest(method: "DELETE",
                                  path: Endpoint.dnsRecord(zoneID: zoneID, recordID: recordID))
        struct AnyResult: Decodable {}
        _ = try await execute(req, decode: AnyResult.self)
    }

    // ---- Access apps ----------------------------------------------------------

    func accessAppCreate(accountID: String, name: String, domain: String) async throws -> AccessApp {
        struct Body: Encodable {
            let name: String
            let domain: String
            let type: String
            let sessionDuration: String
            let appLauncherVisible: Bool
            let autoRedirectToIdentity: Bool
            let allowedIdps: [String]
        }
        let body = Body(
            name: name,
            domain: domain,
            type: "self_hosted",
            sessionDuration: "24h",
            appLauncherVisible: false,
            autoRedirectToIdentity: false,
            allowedIdps: []
        )
        let req = try makeRequest(method: "POST",
                                  path: Endpoint.accessApps(accountID: accountID),
                                  body: body)
        return try await execute(req, decode: AccessApp.self)
    }

    func accessAppDelete(accountID: String, appID: String) async throws {
        let req = try makeRequest(method: "DELETE",
                                  path: Endpoint.accessApp(accountID: accountID, appID: appID))
        struct AnyResult: Decodable {}
        _ = try await execute(req, decode: AnyResult.self)
    }

    // ---- Access service tokens ------------------------------------------------

    func accessServiceTokenCreate(accountID: String, name: String) async throws -> AccessServiceToken {
        struct Body: Encodable { let name: String }
        let req = try makeRequest(method: "POST",
                                  path: Endpoint.accessServiceTokens(accountID: accountID),
                                  body: Body(name: name))
        return try await execute(req, decode: AccessServiceToken.self)
    }

    func accessServiceTokenDelete(accountID: String, tokenID: String) async throws {
        let req = try makeRequest(method: "DELETE",
                                  path: Endpoint.accessServiceToken(accountID: accountID, tokenID: tokenID))
        struct AnyResult: Decodable {}
        _ = try await execute(req, decode: AnyResult.self)
    }

    // ---- Access policies ------------------------------------------------------

    func accessPolicyCreate(accountID: String, appID: String, name: String, serviceTokenID: String) async throws -> AccessPolicy {
        struct IncludeRule: Encodable {
            struct ServiceTokenRef: Encodable { let tokenId: String }
            let serviceToken: ServiceTokenRef
        }
        struct Body: Encodable {
            let name: String
            let decision: String
            let include: [IncludeRule]
            let precedence: Int
        }
        let body = Body(
            name: name,
            decision: "non_identity",
            include: [IncludeRule(serviceToken: .init(tokenId: serviceTokenID))],
            precedence: 1
        )
        let req = try makeRequest(method: "POST",
                                  path: Endpoint.accessPolicies(accountID: accountID, appID: appID),
                                  body: body)
        return try await execute(req, decode: AccessPolicy.self)
    }

    func accessPolicyDelete(accountID: String, appID: String, policyID: String) async throws {
        let req = try makeRequest(method: "DELETE",
                                  path: Endpoint.accessPolicy(accountID: accountID, appID: appID, policyID: policyID))
        struct AnyResult: Decodable {}
        _ = try await execute(req, decode: AnyResult.self)
    }

    // MARK: - Private helpers

    private func makeRequest(method: String, path: String, body: (any Encodable)? = nil) throws -> URLRequest {
        // appendingPathComponent percent-encodes "?" — preserve the query manually.
        let final: URL
        if path.contains("?") {
            final = URL(string: Self.baseURL.absoluteString + "/" + path)!
        } else {
            final = Self.baseURL.appendingPathComponent(path, isDirectory: false)
        }
        var req = URLRequest(url: final)
        req.httpMethod = method
        applyAuth(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Burrow/1.0 (macOS; com.krzemienski.burrow)", forHTTPHeaderField: "User-Agent")
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    private func applyAuth(to req: inout URLRequest) {
        switch auth {
        case .bearer(let token):
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .legacy(let email, let apiKey):
            req.setValue(email,  forHTTPHeaderField: "X-Auth-Email")
            req.setValue(apiKey, forHTTPHeaderField: "X-Auth-Key")
        }
    }

    /// Execute a request and decode the typed envelope.
    /// Maps non-2xx to CloudflareError. Handles 429 with one Retry-After-aware retry.
    private func execute<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        let result = try await performRequest(request)
        if let retryAfter = result.retryAfter {
            // Single retry after sleeping the Retry-After duration.
            logger.info("CF API 429 — sleeping \(retryAfter)s before retry")
            try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
            let retried = try await performRequest(request)
            return try unwrap(retried, type: type, request: request)
        }
        return try unwrap(result, type: type, request: request)
    }

    private struct RawResponse {
        let data: Data
        let http: HTTPURLResponse
        /// Non-nil only when status == 429 and we should retry.
        let retryAfter: Int?
    }

    private func performRequest(_ request: URLRequest) async throws -> RawResponse {
        let start = Date()
        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        let path = request.url?.path ?? ""
        let method = request.httpMethod ?? "?"

        // Scrub: log path + method + status, never the Authorization value.
        logger.info("CF API \(method, privacy: .public) \(path, privacy: .public) → \(http.statusCode) [\(elapsed)ms]")

        if http.statusCode == 429 {
            let retryAfter: Int
            if let headerVal = http.value(forHTTPHeaderField: "Retry-After"),
               let parsed = Int(headerVal) {
                retryAfter = parsed
            } else {
                retryAfter = 60
            }
            return RawResponse(data: data, http: http, retryAfter: retryAfter)
        }

        return RawResponse(data: data, http: http, retryAfter: nil)
    }

    private func unwrap<T: Decodable>(_ raw: RawResponse, type: T.Type, request: URLRequest) throws -> T {
        let status = raw.http.statusCode

        // 429 after retry — surface as error.
        if status == 429 {
            let retryAfter = raw.retryAfter ?? 60
            throw CloudflareError.rateLimited(retryAfter: retryAfter)
        }

        // 401 — invalid token.
        if status == 401 {
            throw CloudflareError.invalidToken
        }

        // 403 — check error code 9109 for insufficient scope.
        if status == 403 {
            let missing = extractErrorMessages(from: raw.data)
            let codes = extractErrorCodes(from: raw.data)
            if codes.contains(9109) {
                throw CloudflareError.insufficientScope(missing: missing)
            }
            throw CloudflareError.insufficientScope(missing: missing)
        }

        // 404 — not found.
        if status == 404 {
            throw CloudflareError.notFound
        }

        // 409 — conflict.
        if status == 409 {
            let msg = extractErrorMessages(from: raw.data).first ?? "Conflict"
            throw CloudflareError.conflict(message: msg)
        }

        // Non-2xx catch-all.
        guard (200...299).contains(status) else {
            let msg = extractErrorMessages(from: raw.data).first ?? "HTTP \(status)"
            throw CloudflareError.upstream(status: status, message: msg)
        }

        // Decode envelope.
        let envelope: APIEnvelope<T>
        do {
            envelope = try decoder.decode(APIEnvelope<T>.self, from: raw.data)
        } catch {
            let preview = String(data: raw.data.prefix(256), encoding: .utf8) ?? "<non-utf8>"
            logger.error("CF API decode failed: \(error.localizedDescription, privacy: .public) body=\(preview, privacy: .public)")
            throw CloudflareError.upstream(status: status, message: "Decode error: \(error.localizedDescription)")
        }

        guard envelope.success, let result = envelope.result else {
            let msg = envelope.errors.first?.message ?? "success=false, no result"
            let firstCode = envelope.errors.first?.code ?? 0
            if firstCode == 9109 {
                throw CloudflareError.insufficientScope(missing: envelope.errors.map { $0.message })
            }
            throw CloudflareError.upstream(status: status, message: msg)
        }

        return result
    }

    // MARK: - Error extraction helpers

    private func extractErrorMessages(from data: Data) -> [String] {
        struct ErrOnly: Decodable {
            struct E: Decodable { let message: String }
            let errors: [E]
        }
        guard let parsed = try? JSONDecoder().decode(ErrOnly.self, from: data) else { return [] }
        return parsed.errors.map { $0.message }
    }

    private func extractErrorCodes(from data: Data) -> [Int] {
        struct ErrOnly: Decodable {
            struct E: Decodable { let code: Int }
            let errors: [E]
        }
        guard let parsed = try? JSONDecoder().decode(ErrOnly.self, from: data) else { return [] }
        return parsed.errors.map { $0.code }
    }
}
