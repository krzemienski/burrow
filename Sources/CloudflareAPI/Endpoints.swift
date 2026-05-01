// Endpoints.swift
// Burrow — typed paths and the four required token scopes.
//
// String-builder helpers only; the actual HTTP work lives in CloudflareClient.
// Centralizing the paths here keeps PRP §3.3 → code mapping legible.

import Foundation

enum Endpoint {

    static func tokensVerify() -> String { "user/tokens/verify" }
    static func accounts() -> String { "accounts" }
    static func zones() -> String { "zones?per_page=50" }

    static func cfdTunnel(accountID: String) -> String {
        "accounts/\(accountID)/cfd_tunnel"
    }

    static func cfdTunnel(accountID: String, tunnelID: String) -> String {
        "accounts/\(accountID)/cfd_tunnel/\(tunnelID)"
    }

    static func cfdTunnelToken(accountID: String, tunnelID: String) -> String {
        "accounts/\(accountID)/cfd_tunnel/\(tunnelID)/token"
    }

    static func cfdTunnelConfigurations(accountID: String, tunnelID: String) -> String {
        "accounts/\(accountID)/cfd_tunnel/\(tunnelID)/configurations"
    }

    static func dnsRecords(zoneID: String) -> String {
        "zones/\(zoneID)/dns_records"
    }

    static func dnsRecord(zoneID: String, recordID: String) -> String {
        "zones/\(zoneID)/dns_records/\(recordID)"
    }

    static func accessApps(accountID: String) -> String {
        "accounts/\(accountID)/access/apps"
    }

    static func accessApp(accountID: String, appID: String) -> String {
        "accounts/\(accountID)/access/apps/\(appID)"
    }

    static func accessPolicies(accountID: String, appID: String) -> String {
        "accounts/\(accountID)/access/apps/\(appID)/policies"
    }

    static func accessPolicy(accountID: String, appID: String, policyID: String) -> String {
        "accounts/\(accountID)/access/apps/\(appID)/policies/\(policyID)"
    }

    static func accessServiceTokens(accountID: String) -> String {
        "accounts/\(accountID)/access/service_tokens"
    }

    static func accessServiceToken(accountID: String, tokenID: String) -> String {
        "accounts/\(accountID)/access/service_tokens/\(tokenID)"
    }
}

/// The four scopes Burrow requires. Surfaced verbatim in the wizard
/// (with copy-to-clipboard buttons) and in Settings → Cloudflare.
enum CloudflareScope {

    static let required: [String] = [
        "Account → Cloudflare Tunnel → Edit",
        "Zone → DNS → Edit",
        "Zone → Zone → Read",
        "Account → Account Settings → Read"
    ]

    /// Apple-style permissions identifier for diff'ing against
    /// the response of /user/tokens/verify (Phase 2 expands this
    /// to map the human strings above to the API's permission_groups
    /// schema).
    static let identifiers: [String] = [
        "com.cloudflare.api.account.cfd_tunnel.edit",
        "com.cloudflare.api.zone.dns.edit",
        "com.cloudflare.api.zone.zone.read",
        "com.cloudflare.api.account.settings.read"
    ]
}
