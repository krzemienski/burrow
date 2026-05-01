// TokenVerify.swift
// Burrow — response shape for /user/tokens/verify.

import Foundation

struct TokenVerify: Decodable, Hashable {
    let id: String
    let status: String        // "active" on success
}
