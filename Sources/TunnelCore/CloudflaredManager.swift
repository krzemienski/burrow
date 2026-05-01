// CloudflaredManager.swift
// Burrow — owns the cloudflared child Process and the tunnel state machine.
//
// Phase 4 deliverable. PRP §5.1 canonical streaming pattern.
//
// D-C addition: ring buffer of last 500 stderr lines for the Dashboard
// "Recent activity" scroll; severity inferred from cloudflared's `INF/WRN/ERR`
// prefix. Plus an AsyncStream of state transitions so the Notifier and
// Dashboard can react without polling.

import Foundation
import OSLog

// MARK: - Log line type (Dashboard ring buffer)

/// One scrubbed cloudflared stderr line, suitable for the Dashboard scroll.
struct TunnelLogLine: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let line: String
    let severity: Severity

    enum Severity: String, Sendable, Equatable {
        case info, warn, error
    }
}

actor CloudflaredManager {

    static let shared = CloudflaredManager()

    // MARK: - Public state

    private(set) var state: TunnelState = .idle

    // MARK: - Private

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    /// Set to true just before we send SIGTERM so terminationHandler
    /// knows not to flip state to .failed.
    private var userInitiatedStop = false

    private var reconnectAttempt: Int = 0
    private let backoffSeconds: [UInt64] = [2, 4, 8, 16, 30]

    // MARK: - D-C ring buffer (Dashboard log tail)

    /// Last 500 cloudflared stderr lines, oldest at index 0.
    private var ringBuffer: [TunnelLogLine] = []
    private let ringCapacity = 500

    /// Continuations that want every new log line streamed to them.
    /// Dashboard creates one via `logStream()` on appear and cancels on disappear.
    private var logContinuations: [UUID: AsyncStream<TunnelLogLine>.Continuation] = [:]

    /// State-transition continuations. Notifier + Dashboard subscribe to these
    /// so they don't have to poll `state` on a Timer for transition detection.
    private var stateContinuations: [UUID: AsyncStream<TunnelState>.Continuation] = [:]

    // MARK: - Severity regex (matches cloudflared's `2026-04-30T...Z INF ...` format)

    private static let severityRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\d{4}-\d{2}-\d{2}T\S+\s+(INF|WRN|WARN|ERR|ERROR)"#,
        options: []
    )

    // MARK: - Lifecycle

    /// Start a tunnel using the run token from Keychain.
    /// Throws CloudflaredManagerError.binaryNotFound if the cloudflared binary
    /// cannot be located, or rethrows any Process.run() error.
    func start(runToken: String) async throws {
        // Locate the binary (consult preferences for a custom path override).
        let customPath = PreferencesStore.shared.customCloudflaredPath
        guard let binaryURL = BinaryLocator.locate(customPath: customPath) else {
            Log.tunnel.error("cloudflared binary not found — aborting start")
            setState(.failed(reason: "cloudflared not found. Install with: brew install cloudflared"))
            throw CloudflaredManagerError.binaryNotFound
        }

        Log.tunnel.info("cloudflared binary: \(binaryURL.path, privacy: .public)")

        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["tunnel", "run", "--token", runToken]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = errPipe

        // Drain stdout silently (cloudflared info logs go to stderr).
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let _ = handle.availableData  // drain to prevent pipe-full blockage
        }

        // Stream stderr: scrub token, route to OSLog, append to ring buffer, drive state machine.
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil  // EOF — process has exited
                return
            }
            let raw = String(data: data, encoding: .utf8) ?? ""
            let lines = raw.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty {
                let scrubbed = line.replacingOccurrences(
                    of: #"--token \S+"#,
                    with: "--token <REDACTED>",
                    options: .regularExpression
                )

                // Severity: parse cloudflared's `<ISO-ts>  INF/WRN/ERR ...` prefix.
                let severity = Self.parseSeverity(scrubbed)

                switch severity {
                case .error:
                    Log.tunnel.error("\(scrubbed, privacy: .public)")
                case .warn:
                    Log.tunnel.warning("\(scrubbed, privacy: .public)")
                case .info:
                    Log.tunnel.info("\(scrubbed, privacy: .public)")
                }

                // Append to the Dashboard ring buffer + fan out to subscribers.
                let logLine = TunnelLogLine(id: UUID(), timestamp: Date(), line: scrubbed, severity: severity)
                Task { await self?.appendLogLine(logLine) }

                // State machine transitions from PRP §3.5 / cloudflared-cli-lifecycle skill.
                if scrubbed.contains("Registered tunnel connection") {
                    Task { await self?.markRunning() }
                }
            }
        }

        // Observe process termination.
        proc.terminationHandler = { [weak self] p in
            Task { await self?.handleExit(code: p.terminationStatus) }
        }

        // Store references before run so stop() can find them.
        self.process    = proc
        self.stdoutPipe = outPipe
        self.stderrPipe = errPipe
        self.userInitiatedStop = false

        setState(.starting)
        Log.tunnel.info("cloudflared starting")

        try proc.run()
        Log.tunnel.info("cloudflared launched pid=\(proc.processIdentifier)")
    }

    /// Stop the tunnel gracefully. SIGTERM → 5 s grace → SIGKILL.
    func stop() async {
        guard let proc = process, proc.isRunning else {
            setState(.stopped)
            return
        }

        userInitiatedStop = true

        // Phase 1: SIGTERM — cloudflared drains active connections gracefully.
        proc.terminate()
        Log.tunnel.info("SIGTERM sent pid=\(proc.processIdentifier)")

        // Phase 2: 5-second grace window, polling every 100 ms.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while proc.isRunning, ContinuousClock.now < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Phase 3: escalate to SIGKILL if still alive.
        if proc.isRunning {
            Log.tunnel.warning("SIGKILL escalation pid=\(proc.processIdentifier)")
            kill(proc.processIdentifier, SIGKILL)
        }

        setState(.stopped)
        process = nil
    }

    /// Restart with a fresh run token. Used by menu bar Reconnect action.
    func restart(runToken: String) async throws {
        await stop()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await start(runToken: runToken)
    }

    // MARK: - Reconnect logic (Phase 7)

    /// Called by NetworkMonitor on `.unsatisfied → .satisfied` transitions.
    /// Called by PowerObserver on `didWakeNotification`.
    func reconnectIfNeeded(runToken: String) async {
        // If the user explicitly stopped the tunnel, don't auto-recover.
        guard case .stopped = state else { return }
        // Only reconnect for non-user-initiated stops (failed / reconnecting).
        // Phase 7 expands this logic with full backoff management.
    }

    // MARK: - Private state transitions

    private func markRunning() {
        Log.tunnel.info("cloudflared tunnel connection registered — state → .running")
        // Use the configured hostname so the Dashboard + Notifier have something
        // useful to render. tunnelID is informational only — Dashboard reads from prefs.
        let hostname = PreferencesStore.shared.fullyQualifiedHostname ?? ""
        let tunnelID = PreferencesStore.shared.tunnelID ?? ""
        setState(.running(tunnelID: tunnelID, hostname: hostname, since: Date()))
    }

    private func handleExit(code: Int32) {
        Log.tunnel.info("cloudflared exited code=\(code)")

        // Tear down pipe handlers to avoid dangling references.
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil

        if userInitiatedStop {
            // Normal user-initiated shutdown; already transitioned to .stopped in stop().
            return
        }

        if code == 0 {
            setState(.stopped)
        } else {
            setState(.failed(reason: "cloudflared exited with code \(code)"))
            Log.tunnel.error("cloudflared unexpected exit code=\(code)")
        }
    }

    // MARK: - State change broadcast

    /// Set the state and notify all stateStream() subscribers.
    /// All internal state mutations should funnel through here so observers
    /// (Notifier, Dashboard, MenuBar) get every transition.
    private func setState(_ new: TunnelState) {
        state = new
        for (_, cont) in stateContinuations {
            cont.yield(new)
        }
    }

    // MARK: - D-C ring buffer accessors (public to actor consumers)

    /// Append a log line, evict oldest beyond capacity, fan out to subscribers.
    private func appendLogLine(_ line: TunnelLogLine) {
        ringBuffer.append(line)
        if ringBuffer.count > ringCapacity {
            ringBuffer.removeFirst(ringBuffer.count - ringCapacity)
        }
        for (_, cont) in logContinuations {
            cont.yield(line)
        }
    }

    /// Snapshot the current ring buffer (for Dashboard initial paint).
    func recentLines() -> [TunnelLogLine] {
        ringBuffer
    }

    /// Subscribe to a stream of log lines as they arrive.
    /// Cancelling the returned task unsubscribes.
    func logStream() -> AsyncStream<TunnelLogLine> {
        AsyncStream { continuation in
            let id = UUID()
            self.logContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeLogContinuation(id: id) }
            }
        }
    }

    private func removeLogContinuation(id: UUID) {
        logContinuations[id] = nil
    }

    /// Subscribe to a stream of state transitions. The current state is yielded
    /// immediately so subscribers don't have to ask for it.
    func stateStream() -> AsyncStream<TunnelState> {
        AsyncStream { continuation in
            let id = UUID()
            self.stateContinuations[id] = continuation
            continuation.yield(self.state)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStateContinuation(id: id) }
            }
        }
    }

    private func removeStateContinuation(id: UUID) {
        stateContinuations[id] = nil
    }

    // MARK: - Severity parser

    private static func parseSeverity(_ scrubbed: String) -> TunnelLogLine.Severity {
        if let regex = severityRegex {
            let range = NSRange(scrubbed.startIndex..<scrubbed.endIndex, in: scrubbed)
            if let match = regex.firstMatch(in: scrubbed, options: [], range: range),
               match.numberOfRanges >= 2,
               let tagRange = Range(match.range(at: 1), in: scrubbed) {
                switch scrubbed[tagRange] {
                case "ERR", "ERROR": return .error
                case "WRN", "WARN":  return .warn
                default:             return .info
                }
            }
        }
        // Fallback heuristic
        if scrubbed.localizedCaseInsensitiveContains("error") { return .error }
        if scrubbed.localizedCaseInsensitiveContains("warn")  { return .warn }
        return .info
    }
}

// MARK: - Error

enum CloudflaredManagerError: Error, LocalizedError {
    case binaryNotFound

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "cloudflared binary not found. Install with: brew install cloudflared"
        }
    }
}
