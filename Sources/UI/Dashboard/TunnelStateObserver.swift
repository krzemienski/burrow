// TunnelStateObserver.swift
// Burrow — bridges the actor-based CloudflaredManager into a MainActor
// @Observable so SwiftUI views can bind directly without polling.
//
// CloudflaredManager remains an `actor` because it's also imported by the
// BurrowE2E CLI tool, which cannot host a SwiftUI/MainActor runloop. This
// observer subscribes to the actor's AsyncStream and republishes state
// for SwiftUI binding.

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class TunnelStateObserver {

    /// Last-known tunnel state. Updated whenever the underlying actor flips.
    var state: TunnelState = .idle

    /// Last 500 cloudflared stderr lines, mirrored from the actor's ring buffer.
    var recentLines: [TunnelLogLine] = []

    private var stateTask: Task<Void, Never>? = nil
    private var logTask: Task<Void, Never>? = nil

    init() {}

    /// Begin observing. Idempotent; safe to call from .onAppear.
    func start() {
        guard stateTask == nil else { return }

        stateTask = Task { [weak self] in
            let stream = await CloudflaredManager.shared.stateStream()
            for await s in stream {
                guard let self else { return }
                await MainActor.run { self.state = s }
            }
        }

        logTask = Task { [weak self] in
            // Seed with current ring buffer
            let initial = await CloudflaredManager.shared.recentLines()
            await MainActor.run { self?.recentLines = initial }

            let stream = await CloudflaredManager.shared.logStream()
            for await line in stream {
                guard let self else { return }
                await MainActor.run {
                    self.recentLines.append(line)
                    if self.recentLines.count > 500 {
                        self.recentLines.removeFirst(self.recentLines.count - 500)
                    }
                }
            }
        }
    }

    /// Stop observing. Safe to call multiple times.
    func stop() {
        stateTask?.cancel()
        logTask?.cancel()
        stateTask = nil
        logTask = nil
    }

    // Note: no deinit task cancellation — @MainActor isolation forbids reading
    // properties from a non-isolated deinit. Callers must invoke stop() in
    // .onDisappear to release the AsyncStream subscriptions cleanly.
}
