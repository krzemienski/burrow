// Zone.swift
// Burrow — Cloudflare DNS zone (the user's domain).

import Foundation

struct Zone: Decodable, Identifiable, Hashable {
    let id: String
    let name: String

    /// Nested object on /zones — we only care about the id.
    let account: AccountRef?

    struct AccountRef: Decodable, Hashable {
        let id: String
    }
}
