// BinaryLocator.swift
// Burrow — find the cloudflared binary on this Mac.
//
// PRP §10 — detect-or-guide strategy. Bundling cloudflared is explicitly
// rejected (binary bloat + upgrade lag). Phase 4 implementation.

import Foundation

enum BinaryLocator {

    /// Probes, in order:
    ///   1. PreferencesStore.customCloudflaredPath if set, executable, exists.
    ///   2. /opt/homebrew/bin/cloudflared (Apple Silicon Homebrew).
    ///   3. /usr/local/bin/cloudflared (Intel Homebrew or pkg install).
    ///   4. PATH lookup via `/usr/bin/which cloudflared`.
    /// Returns the first hit, or nil — the wizard then halts at the
    /// CloudflaredCheckStep with the brew install instructions.
    static func locate(customPath: String? = nil) -> URL? {
        let fm = FileManager.default

        // 1. Custom path from preferences, if set and executable.
        if let custom = customPath, !custom.isEmpty {
            if fm.isExecutableFile(atPath: custom) {
                return URL(fileURLWithPath: custom)
            }
        }

        // 2 & 3. Well-known Homebrew install paths.
        let candidatePaths = [
            "/opt/homebrew/bin/cloudflared",
            "/usr/local/bin/cloudflared"
        ]
        for path in candidatePaths {
            if fm.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // 4. Fallback: ask the shell where `cloudflared` lives on PATH.
        if let whichPath = whichCloudflared(), fm.isExecutableFile(atPath: whichPath) {
            return URL(fileURLWithPath: whichPath)
        }

        return nil
    }

    /// Run `<binary> --version` and parse the semver from the stdout line:
    ///   "cloudflared version 2025.1.4 (built 2025-01-04T00:00:00Z)"
    /// Returns nil if the version string can't be parsed.
    static func version(at url: URL) -> String? {
        let process = Process()
        process.executableURL = url
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // suppress error output during probe

        do {
            try process.run()
        } catch {
            return nil
        }
        // --version is fast; blocking read is acceptable here.
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Match "cloudflared version 2025.1.4" or "2026.3.0" style.
        guard let range = output.range(of: #"version (\d+\.\d+\.\d+)"#, options: .regularExpression) else {
            return nil
        }
        // Extract just the version number after "version ".
        let matched = String(output[range])
        return matched.replacingOccurrences(of: "version ", with: "")
    }

    // MARK: - Private

    /// Run `/usr/bin/which cloudflared` and return the trimmed path, or nil.
    private static func whichCloudflared() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["cloudflared"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
