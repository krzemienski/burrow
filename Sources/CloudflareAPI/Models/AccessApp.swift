// AccessApp.swift
// Burrow — Cloudflare Access application resource.

import Foundation

struct AccessApp: Decodable, Identifiable {
    let id: String
    let name: String
    let domain: String
    let type: String
    let sessionDuration: String?
    let aud: String?
}

struct AccessPolicy: Decodable, Identifiable {
    let id: String
    let name: String
    let decision: String
    let precedence: Int
}

struct AccessServiceToken: Decodable, Identifiable {
    let id: String
    let name: String
    let clientId: String
    /// Only present on create response — never returned again.
    let clientSecret: String?
}
