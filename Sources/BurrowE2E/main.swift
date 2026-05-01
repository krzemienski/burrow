// main.swift
// Burrow — BurrowE2E: end-to-end driver for the full tunnel lifecycle.
//
// Exercises CloudflareClient + CloudflaredManager + KeychainService +
// PreferencesStore against the live Cloudflare API and a real cloudflared
// subprocess. No mocks, no stubs, no test doubles.
//
// Usage:
//   BurrowE2E setup       — provision tunnel + Access app + service token
//   BurrowE2E up          — start cloudflared process, wait for .running
//   BurrowE2E ssh-test    — probe SSH through the live tunnel via Access svc token
//   BurrowE2E down        — stop cloudflared, verify .stopped
//   BurrowE2E teardown    — delete Access policy → app → DNS record → tunnel

import Foundation

// Top-level entry: main.swift is the implicit entry point for a tool target.
// @main cannot coexist with top-level code. Spin an async Task and keep the
// process alive with dispatchMain() until run() calls exit().
Task {
    await BurrowE2E.run()
    exit(0)
}
dispatchMain()

struct BurrowE2E {

    // MARK: - Helpers

    static func env(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    static func require(_ name: String) -> String {
        guard let v = env(name), !v.isEmpty else {
            writeStderr("FATAL: env var \(name) is required but unset")
            exit(2)
        }
        return v
    }

    static func step(_ tag: String, _ message: String) {
        print("[\(tag)] \(message)")
        fflush(stdout)
    }

    static func writeStderr(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    // MARK: - Evidence directory

    static let evidenceDir: URL = {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dir = cwd.appendingPathComponent("e2e-evidence/AT-2")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func writeEvidence(name: String, content: String) {
        let url = evidenceDir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        step("EVIDENCE", "wrote \(url.path) (\(content.utf8.count) bytes)")
    }

    // MARK: - Entry point

    static func run() async {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printHelp()
            exit(0)
        }

        let cmd = args[1]
        do {
            switch cmd {
            case "setup":    try await runSetup()
            case "up":       try await runUp(detach: args.contains("--detach"))
            case "ssh-test": try await runSSHTest()
            case "down":     try await runDown()
            case "teardown": try await runTeardown()
            default:
                writeStderr("Unknown subcommand: \(cmd)")
                printHelp()
                exit(2)
            }
        } catch {
            writeStderr("[\(cmd)] ERROR \(type(of: error)): \(error.localizedDescription)")
            exit(4)
        }
    }

    static func printHelp() {
        print("""
        BurrowE2E — Burrow end-to-end lifecycle driver

        Subcommands:
          setup       Provision tunnel, ingress config, DNS CNAME, Access app + service token
          up          Start cloudflared and wait for .running state
          ssh-test    Probe SSH through the live tunnel via CF Access service token
          down        Stop cloudflared, verify .stopped state
          teardown    Delete Access policy, app, DNS record, and tunnel

        Environment variables (source .env before running):
          CF_API_KEY            37-char Cloudflare Global API Key
          CF_AUTH_EMAIL         Account email
          CF_DOMAIN             Full hostname (e.g. m4.hack.ski)
          SSH_USERNAME          SSH user on the remote host
          SSH_PW                SSH password (used by sshpass)
        """)
    }

    // MARK: - setup

    static func runSetup() async throws {
        let key    = require("CF_API_KEY")
        let email  = require("CF_AUTH_EMAIL")
        let domain = require("CF_DOMAIN")

        let client = CloudflareClient(auth: .legacy(email: email, apiKey: key))
        let prefs  = PreferencesStore.shared

        step("01", "verifyToken")
        let tv = try await client.verifyToken()
        step("01", "ok id=\(tv.id) status=\(tv.status)")

        step("02", "listAccounts")
        let accounts = try await client.listAccounts()
        guard let account = accounts.first else {
            writeStderr("No accounts visible to this credential")
            exit(3)
        }
        step("02", "ok count=\(accounts.count) chosen=\(account.name) id=\(account.id)")

        step("03", "listZones → resolve parent zone of \(domain)")
        let zones = try await client.listZones()
        let domainParts = domain.split(separator: ".").map(String.init)
        let parentZone = domainParts.count >= 2
            ? domainParts.suffix(2).joined(separator: ".")
            : domain
        guard let zone = zones.first(where: { $0.name == parentZone }) else {
            writeStderr("Zone '\(parentZone)' not found. Available: \(zones.map { $0.name }.joined(separator: ", "))")
            exit(3)
        }
        step("03", "ok zone=\(zone.name) id=\(zone.id)")

        let subdomain = domainParts.dropLast(2).joined(separator: ".")
        let tunnelName = "burrow-\(subdomain)"
        step("03", "tunnelName=\(tunnelName) subdomain=\(subdomain)")

        // Reuse existing tunnel if present
        step("04", "listTunnels (check for '\(tunnelName)')")
        let existingTunnels = try await client.listTunnels(accountID: account.id)
        let tunnelID: String
        if let existing = existingTunnels.first(where: { $0.name == tunnelName }) {
            tunnelID = existing.id
            step("04", "REUSE existing id=\(tunnelID)")
        } else {
            step("04", "createTunnel name=\(tunnelName)")
            let t = try await client.createTunnel(accountID: account.id, name: tunnelName)
            tunnelID = t.id
            step("04", "ok id=\(tunnelID) cname=\(t.cnameTarget)")
        }

        step("05", "getTunnelRunToken")
        let runToken = try await client.getTunnelRunToken(accountID: account.id, tunnelID: tunnelID)
        try await KeychainService.shared.setRunToken(runToken, tunnelID: tunnelID)
        step("05", "ok token_len=\(runToken.count) keychain=true")

        step("06", "setIngressConfig hostname=\(domain) port=22")
        try await client.setIngressConfig(accountID: account.id, tunnelID: tunnelID,
                                           hostname: domain, localPort: 22)
        step("06", "ok")

        // Reuse CNAME if already correct
        let cnameTarget = "\(tunnelID).cfargotunnel.com"
        step("07", "findCNAME \(domain)")
        let existingRec = try await client.findCNAME(zoneID: zone.id, name: domain)
        let dnsRecordID: String
        if let rec = existingRec {
            if rec.content == cnameTarget {
                dnsRecordID = rec.id
                step("07", "REUSE existing CNAME id=\(dnsRecordID)")
            } else {
                writeStderr("CNAME \(domain) already points at '\(rec.content)' (expected '\(cnameTarget)'). Remove it manually.")
                exit(3)
            }
        } else {
            step("07", "createCNAME \(domain) → \(cnameTarget)")
            let rec = try await client.createCNAME(zoneID: zone.id, name: domain, target: cnameTarget)
            dnsRecordID = rec.id
            step("07", "ok id=\(dnsRecordID) proxied=\(rec.proxied)")
        }

        step("08", "accessAppCreate name=\(tunnelName) domain=\(domain)")
        let app = try await client.accessAppCreate(accountID: account.id, name: tunnelName, domain: domain)
        step("08", "ok app_id=\(app.id)")

        step("09", "accessServiceTokenCreate name=\(tunnelName)-svc")
        let svcToken = try await client.accessServiceTokenCreate(accountID: account.id,
                                                                  name: "\(tunnelName)-svc")
        guard let clientSecret = svcToken.clientSecret else {
            writeStderr("accessServiceTokenCreate returned no client_secret")
            exit(3)
        }
        step("09", "ok svc_id=\(svcToken.id) client_id_len=\(svcToken.clientId.count) secret=present")

        try await KeychainService.shared.setAccessServiceToken(clientID: svcToken.clientId,
                                                                clientSecret: clientSecret,
                                                                appID: app.id)
        step("09", "svc token stored in keychain appID=\(app.id)")

        step("10", "accessPolicyCreate service-token-allow")
        let policy = try await client.accessPolicyCreate(
            accountID: account.id,
            appID: app.id,
            name: "svc-token-allow",
            serviceTokenID: svcToken.id
        )
        step("10", "ok policy_id=\(policy.id)")

        prefs.selectedAccountID    = account.id
        prefs.selectedZoneID       = zone.id
        prefs.selectedZoneName     = zone.name
        prefs.subdomain            = subdomain
        prefs.tunnelID             = tunnelID
        prefs.tunnelName           = tunnelName
        prefs.accessAppID          = app.id
        prefs.accessServiceTokenID = svcToken.id
        prefs.accessPolicyID       = policy.id
        UserDefaults(suiteName: "com.krzemienski.burrow")?.synchronize()
        step("10", "prefs persisted")

        let out = """
        {
          "tunnel_id": "\(tunnelID)",
          "tunnel_name": "\(tunnelName)",
          "hostname": "\(domain)",
          "dns_record_id": "\(dnsRecordID)",
          "app_id": "\(app.id)",
          "policy_id": "\(policy.id)",
          "service_token_id": "\(svcToken.id)",
          "service_token_client_id_len": \(svcToken.clientId.count),
          "service_token_present": true
        }
        """
        writeEvidence(name: "setup.json", content: out)
        step("SETUP_OK", out)
    }

    // MARK: - up

    static func runUp(detach: Bool) async throws {
        let prefs = PreferencesStore.shared
        guard let tunnelID = prefs.tunnelID else {
            writeStderr("No tunnelID in PreferencesStore — run 'setup' first")
            exit(3)
        }

        step("01", "getRunToken tunnelID=\(tunnelID)")
        guard let runToken = try await KeychainService.shared.getRunToken(tunnelID: tunnelID) else {
            writeStderr("No run token in Keychain for tunnelID=\(tunnelID)")
            exit(3)
        }
        step("01", "ok token_len=\(runToken.count)")

        let manager = CloudflaredManager.shared
        step("02", "manager.start()")
        try await manager.start(runToken: runToken)

        step("02", "polling for .running (30s budget)")
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        var lastLabel = ""
        while ContinuousClock.now < deadline {
            let s = await manager.state
            let label = s.displayLabel
            if label != lastLabel {
                step("STATE", label)
                lastLabel = label
            }
            if case .running = s { break }
            if case .failed(let r) = s {
                writeStderr("cloudflared failed: \(r)")
                exit(4)
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        let final = await manager.state
        guard case .running = final else {
            writeStderr("cloudflared did not reach .running within 30s — last: \(final.displayLabel)")
            exit(4)
        }

        let out = """
        {
          "tunnel_id": "\(tunnelID)",
          "state": "running"
        }
        """
        writeEvidence(name: "up.json", content: out)
        step("UP_OK", out)

        if detach {
            let pidFile = evidenceDir.appendingPathComponent("cloudflared.pid")
            try? "\(ProcessInfo.processInfo.processIdentifier)".write(to: pidFile, atomically: true, encoding: .utf8)
            step("UP_OK", "detach — pid_file=\(pidFile.path)")
            return
        }

        step("UP_OK", "tunnel running — Ctrl-C or 'BurrowE2E down' to stop")
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let src = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
            src.setEventHandler {
                src.cancel()
                cont.resume()
            }
            src.resume()
            signal(SIGINT, SIG_IGN)
        }
        step("UP", "SIGINT received — stopping")
        await manager.stop()
    }

    // MARK: - ssh-test

    static func runSSHTest() async throws {
        let domain  = require("CF_DOMAIN")
        let sshUser = env("SSH_USERNAME") ?? "nick"
        let sshPw   = require("SSH_PW")

        let prefs = PreferencesStore.shared
        guard let appID = prefs.accessAppID else {
            writeStderr("No accessAppID in PreferencesStore — run 'setup' first")
            exit(3)
        }

        step("01", "getAccessServiceToken appID=\(appID)")
        guard let creds = try await KeychainService.shared.getAccessServiceToken(appID: appID) else {
            writeStderr("No Access service token in Keychain for appID=\(appID)")
            exit(3)
        }
        step("01", "ok client_id_len=\(creds.clientID.count) secret_len=\(creds.clientSecret.count)")

        // Use `cloudflared access tcp` (raw-TCP gateway), not `access ssh` (short-lived-cert
        // gateway) — the latter requires the SSH origin to trust the CF CA.
        // Pass service token via TUNNEL_SERVICE_TOKEN_{ID,SECRET} env vars, NOT CLI flags;
        // ssh's argument quoting mangles the secret when it propagates ProxyCommand.
        let proxyCmd = "/opt/homebrew/bin/cloudflared access tcp --hostname %h"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var environment = ProcessInfo.processInfo.environment
        environment["TUNNEL_SERVICE_TOKEN_ID"]     = creds.clientID
        environment["TUNNEL_SERVICE_TOKEN_SECRET"] = creds.clientSecret
        proc.environment = environment
        proc.arguments = [
            "sshpass", "-p", sshPw,
            "ssh",
            "-o", "ProxyCommand=\(proxyCmd)",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=25",
            "-o", "PasswordAuthentication=yes",
            "-o", "PreferredAuthentications=password",
            "-o", "PubkeyAuthentication=no",
            "\(sshUser)@\(domain)",
            "echo BURROW_E2E_OK; uname -n; uname -r; date -u +%FT%TZ; echo BURROW_SENTINEL_$(date +%s)"
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = errPipe

        step("02", "spawn sshpass ssh → \(sshUser)@\(domain)")
        try proc.run()
        proc.waitUntilExit()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let code   = proc.terminationStatus

        writeEvidence(name: "ssh.log",
                      content: "exit_code=\(code)\n---STDOUT---\n\(stdout)\n---STDERR---\n\(stderr)")

        if code == 0 && stdout.contains("BURROW_E2E_OK") {
            step("SSH_OK", stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            writeStderr("SSH_FAIL exit_code=\(code)\nstdout=\(stdout)\nstderr=\(stderr)")
            exit(4)
        }
    }

    // MARK: - down

    static func runDown() async throws {
        let manager = CloudflaredManager.shared
        let before  = await manager.state
        step("01", "state_before=\(before.displayLabel)")

        await manager.stop()

        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            if case .stopped = await manager.state { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let after = await manager.state
        step("01", "state_after=\(after.displayLabel)")

        try await Task.sleep(nanoseconds: 500_000_000)

        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-x", "cloudflared"]
        let pgPipe = Pipe()
        pgrep.standardOutput = pgPipe
        pgrep.standardError  = Pipe()
        try pgrep.run()
        pgrep.waitUntilExit()
        let orphans = (String(data: pgPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        writeEvidence(name: "orphan-check.txt",
                      content: "cloudflared pids after stop: \(orphans.isEmpty ? "(none)" : orphans)\n")

        let out = """
        {
          "state_before": "\(before.displayLabel)",
          "state_after": "\(after.displayLabel)",
          "orphan_pids": "\(orphans.isEmpty ? "none" : orphans)"
        }
        """
        writeEvidence(name: "down.json", content: out)
        step("DOWN_OK", out)
    }

    // MARK: - teardown

    static func runTeardown() async throws {
        let key   = require("CF_API_KEY")
        let email = require("CF_AUTH_EMAIL")

        let client = CloudflareClient(auth: .legacy(email: email, apiKey: key))
        let prefs  = PreferencesStore.shared

        guard let accountID = prefs.selectedAccountID,
              let tunnelID  = prefs.tunnelID else {
            writeStderr("Missing accountID or tunnelID in PreferencesStore — run 'setup' first")
            exit(3)
        }

        var results: [(key: String, val: String)] = []

        // 1. Delete Access policy
        if let appID = prefs.accessAppID, let policyID = prefs.accessPolicyID {
            step("01", "accessPolicyDelete appID=\(appID) policyID=\(policyID)")
            do {
                try await client.accessPolicyDelete(accountID: accountID, appID: appID, policyID: policyID)
                results.append(("policy", "deleted"))
                step("01", "ok")
            } catch CloudflareError.notFound {
                results.append(("policy", "not_found"))
                step("01", "already gone")
            }
        } else {
            results.append(("policy", "skipped"))
            step("01", "skip — no accessPolicyID")
        }

        // 2. Delete Access service token
        if let svcID = prefs.accessServiceTokenID {
            step("02", "accessServiceTokenDelete id=\(svcID)")
            do {
                try await client.accessServiceTokenDelete(accountID: accountID, tokenID: svcID)
                results.append(("service_token", "deleted"))
                step("02", "ok")
            } catch CloudflareError.notFound {
                results.append(("service_token", "not_found"))
                step("02", "already gone")
            }
        } else {
            results.append(("service_token", "skipped"))
            step("02", "skip — no accessServiceTokenID")
        }

        // 3. Delete Access app
        if let appID = prefs.accessAppID {
            step("03", "accessAppDelete appID=\(appID)")
            do {
                try await client.accessAppDelete(accountID: accountID, appID: appID)
                results.append(("app", "deleted"))
                step("03", "ok")
            } catch CloudflareError.notFound {
                results.append(("app", "not_found"))
                step("03", "already gone")
            }
            try? await KeychainService.shared.deleteAccessServiceToken(appID: appID)
        } else {
            results.append(("app", "skipped"))
            step("03", "skip — no accessAppID")
        }

        // 4. Delete DNS CNAME
        if let zoneID = prefs.selectedZoneID, let hostname = prefs.fullyQualifiedHostname {
            step("04", "findCNAME \(hostname)")
            if let rec = try? await client.findCNAME(zoneID: zoneID, name: hostname) {
                try await client.deleteDNSRecord(zoneID: zoneID, recordID: rec.id)
                results.append(("dns_record", "deleted"))
                step("04", "ok id=\(rec.id)")
            } else {
                results.append(("dns_record", "not_found"))
                step("04", "already gone")
            }
        } else {
            results.append(("dns_record", "skipped"))
            step("04", "skip — no zoneID or hostname")
        }

        // 5. Delete tunnel
        step("05", "deleteTunnel id=\(tunnelID)")
        do {
            try await client.deleteTunnel(accountID: accountID, tunnelID: tunnelID)
            results.append(("tunnel", "deleted"))
            step("05", "ok")
        } catch CloudflareError.notFound {
            results.append(("tunnel", "not_found"))
            step("05", "already gone")
        }

        try? await KeychainService.shared.deleteRunToken(tunnelID: tunnelID)

        prefs.tunnelID              = nil
        prefs.tunnelName            = nil
        prefs.accessAppID           = nil
        prefs.accessServiceTokenID  = nil
        prefs.accessPolicyID        = nil
        UserDefaults(suiteName: "com.krzemienski.burrow")?.synchronize()

        let body = results.map { "  \"\($0.key)\": \"\($0.val)\"" }.joined(separator: ",\n")
        let out  = "{\n\(body)\n}"
        writeEvidence(name: "teardown.json", content: out)
        step("TEARDOWN_OK", out)
    }
}
