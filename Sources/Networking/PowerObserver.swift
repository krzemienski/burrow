// PowerObserver.swift
// Burrow — listens for sleep/wake and notifies the tunnel manager.
//
// Phase 7 deliverable. NSWorkspace publishes the notifications;
// we forward willSleep → stop and didWake → 3 s delay → start.

import AppKit

final class PowerObserver {

    var onWillSleep: (() async -> Void)?
    var onDidWake: (() async -> Void)?

    private var willSleepObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?

    func start() {
        let nc = NSWorkspace.shared.notificationCenter

        willSleepObserver = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.onWillSleep?() }
        }

        didWakeObserver = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self.onDidWake?()
            }
        }
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        willSleepObserver.map { nc.removeObserver($0) }
        didWakeObserver.map { nc.removeObserver($0) }
    }
}
