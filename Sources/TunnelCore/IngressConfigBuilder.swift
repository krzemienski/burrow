// IngressConfigBuilder.swift
// Burrow — assemble the ingress payload for the Cloudflare API.
//
// We use cloud-managed config (`config_src: "cloudflare"`), so this
// produces the JSON body that is PUT to /cfd_tunnel/{id}/configurations.
// Local YAML config is only generated in the Advanced override path (v1.1+).

import Foundation

enum IngressConfigBuilder {

    /// Build the ingress payload for a single SSH route.
    ///
    /// The catch-all `http_status:404` rule is appended automatically — the
    /// CF API rejects any ingress array whose final rule has a `hostname`
    /// (PRP §3.6 gotcha #6).
    static func payload(hostname: String, localPort: Int = 22) -> [String: Any] {
        return [
            "config": [
                "ingress": [
                    [
                        "hostname": hostname,
                        "service":  "ssh://localhost:\(localPort)"
                    ],
                    [
                        "service": "http_status:404"
                    ]
                ]
            ]
        ]
    }
}
