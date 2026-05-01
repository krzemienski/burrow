// PersistRunner.swift
// Burrow — P3-T2 persistence round-trip executable.
//
// Two-process round-trip: invoke once with "write" to push known values
// into Keychain + UserDefaults, then quit. Re-invoke with "verify" in a
// fresh process to read them back and assert they match.

import Foundation

@main
struct PersistRunner {
    static let knownToken      = "cfut_test_persist_burrow"
    static let knownTunnelID   = "test-tunnel-uuid-aaaa-bbbb-cccc-dddddddddddd"
    static let knownRunToken   = "runtok_test_persist_burrow"
    static let knownSubdomain  = "m4-test-persist"
    static let knownLocalPort  = 2222
    static let knownSSHUser    = "nick"

    static func step(_ tag: String, _ message: String) {
        print("[\(tag)] \(message)")
    }

    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            step("ERROR", "usage: BurrowPersist <write|verify|cleanup>")
            exit(2)
        }
        let mode = args[1]

        do {
            switch mode {
            case "write":
                step("WRITE", "begin")
                try await KeychainService.shared.setAPIToken(knownToken)
                step("WRITE", "ok api-token len=\(knownToken.count)")
                try await KeychainService.shared.setRunToken(knownRunToken, tunnelID: knownTunnelID)
                step("WRITE", "ok run-token tunnelID=\(knownTunnelID) len=\(knownRunToken.count)")

                let prefs = PreferencesStore.shared
                prefs.subdomain   = knownSubdomain
                prefs.localPort   = knownLocalPort
                prefs.sshUsername = knownSSHUser
                step("WRITE", "ok prefs subdomain=\(prefs.subdomain) port=\(prefs.localPort) user=\(prefs.sshUsername)")

                UserDefaults(suiteName: "com.krzemienski.burrow")?.synchronize()
                step("WROTE", "all 5 keys persisted")

            case "verify":
                step("READ", "begin (fresh process)")
                let api  = try await KeychainService.shared.getAPIToken()
                let run  = try await KeychainService.shared.getRunToken(tunnelID: knownTunnelID)
                let prefs = PreferencesStore.shared

                var ok = true
                if api == knownToken { step("READ", "api-token MATCH") }
                else { step("READ", "api-token MISMATCH got=\(api ?? "<nil>")"); ok = false }

                if run == knownRunToken { step("READ", "run-token MATCH") }
                else { step("READ", "run-token MISMATCH got=\(run ?? "<nil>")"); ok = false }

                if prefs.subdomain == knownSubdomain { step("READ", "subdomain MATCH") }
                else { step("READ", "subdomain MISMATCH got=\(prefs.subdomain)"); ok = false }

                if prefs.localPort == knownLocalPort { step("READ", "localPort MATCH") }
                else { step("READ", "localPort MISMATCH got=\(prefs.localPort)"); ok = false }

                if prefs.sshUsername == knownSSHUser { step("READ", "sshUsername MATCH") }
                else { step("READ", "sshUsername MISMATCH got=\(prefs.sshUsername)"); ok = false }

                if ok {
                    step("READ-MATCH", "PASS — all 5 round-trip values match")
                } else {
                    step("READ-MATCH", "FAIL")
                    exit(3)
                }

            case "cleanup":
                step("CLEANUP", "begin")
                try await KeychainService.shared.deleteAPIToken()
                try await KeychainService.shared.deleteRunToken(tunnelID: knownTunnelID)
                let prefs = PreferencesStore.shared
                prefs.subdomain   = "m4"
                prefs.localPort   = 22
                prefs.sshUsername = NSUserName()
                UserDefaults(suiteName: "com.krzemienski.burrow")?.synchronize()
                step("CLEANUP", "ok")

            default:
                step("ERROR", "unknown mode: \(mode)")
                exit(2)
            }
        } catch {
            step("ERROR", "\(type(of: error)): \(error.localizedDescription)")
            exit(4)
        }
    }
}
