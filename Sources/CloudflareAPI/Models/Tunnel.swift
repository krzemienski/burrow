// Tunnel.swift
// Burrow — Cloudflare named tunnel (cfd_tunnel resource).

import Foundation

struct Tunnel: Decodable, Identifiable, Hashable {
    let id: String
    let name: String

    /// Present only on the create response. Stored separately in Keychain.
    /// Subsequent fetches via GET /token return the bare string instead.
    let token: String?

    /// CNAME target follows the convention <id>.cfargotunnel.com.
    var cnameTarget: String { "\(id).cfargotunnel.com" }
}
