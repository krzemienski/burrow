// Account.swift
// Burrow — Cloudflare account record (subset we use).

import Foundation

struct Account: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
}
