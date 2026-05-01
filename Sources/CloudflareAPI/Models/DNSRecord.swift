// DNSRecord.swift
// Burrow — Cloudflare DNS record (we only ever create CNAMEs).

import Foundation

struct DNSRecord: Decodable, Identifiable, Hashable {
    let id: String
    let type: String          // always "CNAME" for Burrow's records
    let name: String          // FQDN, e.g. "m4.nick.dev"
    let content: String       // the cfargotunnel.com target
    let proxied: Bool
    let ttl: Int              // 1 == automatic
}
