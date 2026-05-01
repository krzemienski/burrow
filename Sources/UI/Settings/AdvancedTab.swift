// AdvancedTab.swift
// Burrow — Settings → Advanced.
// PRP §FR-5.5.

import SwiftUI
import AppKit

struct AdvancedTab: View {

    private let prefs = PreferencesStore.shared

    @State private var binaryPath: String = ""
    @State private var useCustomYAML: Bool = false
    @State private var yamlOverride: String = ""
    @State private var yamlError: String? = nil
    @State private var logLines: [String] = []
    @State private var logTimer: Timer? = nil

    var body: some View {
        Form {
            Section("cloudflared Binary") {
                HStack {
                    TextField("/opt/homebrew/bin/cloudflared", text: $binaryPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("cloudflared binary path")
                        .onChange(of: binaryPath) { _, newValue in
                            prefs.customCloudflaredPath = newValue.isEmpty ? nil : newValue
                        }

                    Button("Browse…") {
                        pickBinaryPath()
                    }
                    .accessibilityLabel("Browse for cloudflared binary")
                }

                if let detected = BinaryLocator.locate(customPath: binaryPath.isEmpty ? nil : binaryPath) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                        Text(detected.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let ver = BinaryLocator.version(at: detected) {
                            Text("v\(ver)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .imageScale(.small)
                        Text("Not found. Install with: brew install cloudflared")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Ingress YAML Override") {
                Toggle("Use custom ingress YAML", isOn: $useCustomYAML)
                    .accessibilityLabel("Enable custom ingress YAML override")

                if useCustomYAML {
                    TextEditor(text: $yamlOverride)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .border(Color.secondary.opacity(0.3))
                        .accessibilityLabel("Custom ingress YAML content")
                        .onChange(of: yamlOverride) { _, newValue in
                            validateYAML(newValue)
                        }

                    if let err = yamlError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Live Logs") {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(logLines.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                                    .id(idx)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                    .frame(minHeight: 120, maxHeight: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .border(Color.secondary.opacity(0.3))
                    .onChange(of: logLines.count) { _, _ in
                        if let last = logLines.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onAppear { startLogTail() }
                .onDisappear { stopLogTail() }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            binaryPath = prefs.customCloudflaredPath ?? ""
        }
    }

    // MARK: - Binary path picker

    private func pickBinaryPath() {
        let panel = NSOpenPanel()
        panel.title = "Select cloudflared binary"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")

        if panel.runModal() == .OK, let url = panel.url {
            binaryPath = url.path
            prefs.customCloudflaredPath = url.path
        }
    }

    // MARK: - YAML validation (lightweight structural check)

    private func validateYAML(_ text: String) {
        yamlError = nil
        guard !text.isEmpty else { return }
        // Minimal check: must contain "ingress:" key
        if !text.contains("ingress:") {
            yamlError = "YAML must contain an 'ingress:' block."
        }
    }

    // MARK: - Log tail (poll from OSLog store via log stream)

    private func startLogTail() {
        // Kick off a background process to stream tunnel logs
        logLines = ["— waiting for tunnel logs —"]
        let t = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            fetchRecentLogs()
        }
        logTimer = t
        fetchRecentLogs()
    }

    private func stopLogTail() {
        logTimer?.invalidate()
        logTimer = nil
    }

    private func fetchRecentLogs() {
        Task.detached(priority: .background) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "show",
                "--predicate", "subsystem == \"com.krzemienski.burrow\" AND category == \"tunnel\"",
                "--style", "compact",
                "--last", "5m"
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let lines = output.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .suffix(1000)
                    .map { String($0) }
                await MainActor.run {
                    if !lines.isEmpty {
                        logLines = lines
                    }
                }
            } catch {
                // log command unavailable — silently skip
            }
        }
    }
}
