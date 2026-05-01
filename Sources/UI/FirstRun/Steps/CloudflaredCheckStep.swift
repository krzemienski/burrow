// CloudflaredCheckStep.swift  — Phase 6
// Calls BinaryLocator.locate(); if nil, shows brew install snippet
// with copy button + link to https://github.com/cloudflare/cloudflared/releases.

import SwiftUI
import AppKit

struct CloudflaredCheckStep: View {

    var onFound: (URL) -> Void
    var onContinue: () -> Void

    @State private var checkState: CheckState = .checking

    enum CheckState {
        case checking
        case found(URL, version: String?)
        case missing
    }

    private let brewInstall = "brew install cloudflared"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("cloudflared Binary")
                .font(.title2.weight(.semibold))

            Text("Burrow uses the cloudflared binary to manage your tunnel. Let's check if it's installed.")
                .foregroundStyle(.secondary)

            switch checkState {
            case .checking:
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Searching for cloudflared…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 30)

            case .found(let url, let version):
                VStack(alignment: .leading, spacing: 8) {
                    Label("cloudflared found", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text(url.path)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if let v = version {
                            Text("v\(v)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            case .missing:
                VStack(alignment: .leading, spacing: 12) {
                    Label("cloudflared not found", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.headline)

                    Text("Install cloudflared with Homebrew:")
                        .font(.callout)

                    HStack {
                        Text(brewInstall)
                            .font(.system(.body, design: .monospaced))
                            .padding(10)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(brewInstall, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .accessibilityLabel("Copy brew install command")
                    }

                    HStack(spacing: 12) {
                        Button("Manual install on GitHub →") {
                            NSWorkspace.shared.open(
                                URL(string: "https://github.com/cloudflare/cloudflared/releases")!
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Open cloudflared releases on GitHub")

                        Button("Check Again") {
                            runCheck()
                        }
                        .accessibilityLabel("Re-check for cloudflared binary")
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFound)
                .accessibilityLabel("Continue to tunnel creation")
                .keyboardShortcut(.return)
            }
        }
        .padding(32)
        .onAppear { runCheck() }
    }

    private var isFound: Bool {
        if case .found = checkState { return true }
        return false
    }

    private func runCheck() {
        checkState = .checking
        Task.detached(priority: .userInitiated) {
            let url = BinaryLocator.locate()
            let version = url.flatMap { BinaryLocator.version(at: $0) }
            await MainActor.run {
                if let u = url {
                    checkState = .found(u, version: version)
                    onFound(u)
                } else {
                    checkState = .missing
                }
            }
        }
    }
}
