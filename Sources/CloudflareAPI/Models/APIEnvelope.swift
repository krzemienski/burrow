// APIEnvelope.swift
// Burrow — generic Cloudflare API v4 response envelope.
//
// Every CF v4 response wraps the actual payload in this shape:
//   {
//     "result": <T or null>,
//     "success": true|false,
//     "errors": [...],
//     "messages": [...]
//   }

import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let result: T?
    let success: Bool
    let errors: [APIError]
    let messages: [APIMessage]
}

struct APIError: Decodable, Equatable {
    let code: Int
    let message: String
}

struct APIMessage: Decodable, Equatable {
    let code: Int?
    let message: String
}
