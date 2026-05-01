// CloudflareError.swift
// Burrow — typed errors from the Cloudflare API.
//
// Every endpoint method in CloudflareClient maps non-2xx responses
// onto one of these cases. The wizard and Settings tabs render
// remediation copy keyed off the case (e.g. .insufficientScope shows
// the missing-scope diff with copy buttons).

import Foundation

enum CloudflareError: Error, LocalizedError, Equatable {

    /// 401 — token does not pass /user/tokens/verify.
    case invalidToken

    /// 403 — token is valid but missing one or more required scopes.
    /// `missing` lists the scopes the user must add.
    case insufficientScope(missing: [String])

    /// 429 — rate limited. `retryAfter` is the value of the
    /// Retry-After header (seconds), or 60 if missing.
    case rateLimited(retryAfter: Int)

    /// 404 — resource (zone, tunnel, DNS record) not found.
    case notFound

    /// 409 — resource conflict (e.g. tunnel name already exists,
    /// DNS record collision on subdomain change).
    case conflict(message: String)

    /// 5xx or unparseable body — last-resort bucket. The `message`
    /// is taken from the first entry of the API response's `errors[]`
    /// when present, else a generic string.
    case upstream(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Cloudflare API token rejected. Re-enter in Settings → Cloudflare."
        case .insufficientScope(let missing):
            return "Missing scopes: \(missing.joined(separator: ", "))"
        case .rateLimited(let retryAfter):
            return "Cloudflare rate-limited the request. Retrying in \(retryAfter)s."
        case .notFound:
            return "Cloudflare resource not found."
        case .conflict(let message):
            return "Conflict: \(message)"
        case .upstream(let status, let message):
            return "Cloudflare API error (HTTP \(status)): \(message)"
        }
    }
}
