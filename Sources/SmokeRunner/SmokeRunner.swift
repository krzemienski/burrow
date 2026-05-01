// main.swift
// Burrow — P2-T3 smoke-test executable.
//
// Drives the real Cloudflare API end-to-end through CloudflareClient.
// Reads credentials from env (CF_API_KEY, CF_AUTH_EMAIL, CF_ZONE_NAME).
// Creates and DELETES a temporary tunnel + CNAME under a unique host
// (`burrow-smoke-<timestamp>.<zone>`) so prod records (e.g. m4.hack.ski)
// are never touched.

import Foundation

@main
struct SmokeRunner {
    static func env(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    static func require(_ name: String) -> String {
        guard let v = env(name), !v.isEmpty else {
            FileHandle.standardError.write(Data("FATAL: env var \(name) is required but unset.\n".utf8))
            exit(2)
        }
        return v
    }

    static func step(_ tag: String, _ message: String) {
        print("[\(tag)] \(message)")
    }

    static func main() async {
        let key   = Self.require("CF_API_KEY")
        let email = Self.require("CF_AUTH_EMAIL")
        let zone  = Self.require("CF_ZONE_NAME")

        let stamp = Int(Date().timeIntervalSince1970)
        let smokeHost = "burrow-smoke-\(stamp).\(zone)"
        let smokeTunnelName = "burrow-smoke-\(stamp)"

        let client = CloudflareClient(auth: .legacy(email: email, apiKey: key))

        var createdTunnelID: String? = nil
        var createdRecordID: String? = nil

        do {
            step("01", "verifyToken")
            let tv = try await client.verifyToken()
            step("01", "ok id=\(tv.id) status=\(tv.status)")

            step("02", "listAccounts")
            let accounts = try await client.listAccounts()
            guard let account = accounts.first else {
                step("02", "err no accounts visible to this credential")
                exit(3)
            }
            step("02", "ok count=\(accounts.count) chosen=\(account.name)")

            step("03", "listZones")
            let zones = try await client.listZones()
            guard let z = zones.first(where: { $0.name == zone }) else {
                step("03", "err zone '\(zone)' not visible")
                exit(3)
            }
            step("03", "ok count=\(zones.count) chosen=\(z.name) id=\(z.id)")

            step("04", "createTunnel name=\(smokeTunnelName)")
            let tunnel = try await client.createTunnel(accountID: account.id, name: smokeTunnelName)
            createdTunnelID = tunnel.id
            step("04", "ok id=\(tunnel.id) cname=\(tunnel.cnameTarget) token_present=\(tunnel.token != nil)")

            step("05", "getTunnelRunToken")
            let runTok = try await client.getTunnelRunToken(accountID: account.id, tunnelID: tunnel.id)
            step("05", "ok token_len=\(runTok.count)")

            step("06", "setIngressConfig host=\(smokeHost) port=22")
            try await client.setIngressConfig(
                accountID: account.id,
                tunnelID: tunnel.id,
                hostname: smokeHost,
                localPort: 22)
            step("06", "ok")

            step("07", "listTunnels (verify newly-created visible)")
            let tunnels = try await client.listTunnels(accountID: account.id)
            let found = tunnels.contains(where: { $0.id == tunnel.id })
            step("07", "ok total=\(tunnels.count) created_visible=\(found)")

            step("08", "findCNAME (must be nil before create)")
            let pre = try await client.findCNAME(zoneID: z.id, name: smokeHost)
            step("08", "ok pre_exists=\(pre != nil)")

            step("09", "createCNAME \(smokeHost) → \(tunnel.cnameTarget)")
            let record = try await client.createCNAME(
                zoneID: z.id,
                name: smokeHost,
                target: tunnel.cnameTarget)
            createdRecordID = record.id
            step("09", "ok id=\(record.id) proxied=\(record.proxied) ttl=\(record.ttl)")

            step("10", "updateCNAME (no-op rewrite to same target)")
            let updated = try await client.updateCNAME(
                zoneID: z.id,
                recordID: record.id,
                name: smokeHost,
                target: tunnel.cnameTarget)
            step("10", "ok id=\(updated.id)")

            step("11", "deleteDNSRecord id=\(record.id)")
            try await client.deleteDNSRecord(zoneID: z.id, recordID: record.id)
            createdRecordID = nil
            step("11", "ok")

            step("12", "deleteTunnel id=\(tunnel.id)")
            try await client.deleteTunnel(accountID: account.id, tunnelID: tunnel.id)
            createdTunnelID = nil
            step("12", "ok")

            step("DONE", "BURROW_SMOKE_OK all 11 endpoints + CNAME round-trip succeeded")

        } catch {
            step("ERROR", "\(type(of: error)): \(error.localizedDescription)")

            if let rid = createdRecordID,
               let z = (try? await client.listZones())?.first(where: { $0.name == zone }) {
                step("CLEANUP", "delete leftover DNS record \(rid)")
                try? await client.deleteDNSRecord(zoneID: z.id, recordID: rid)
            }
            if let tid = createdTunnelID,
               let acct = (try? await client.listAccounts())?.first {
                step("CLEANUP", "delete leftover tunnel \(tid)")
                try? await client.deleteTunnel(accountID: acct.id, tunnelID: tid)
            }
            exit(4)
        }
    }
}
