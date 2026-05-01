// DoneStep.swift  — Phase 6
// Final confirmation. Shows the SSH command with copy button. Closes wizard.

import SwiftUI
import AppKit

struct DoneStep: View {

    var onDismiss: () -> Void

    @State private var copyConfirmed: Bool = false

    private let prefs = PreferencesStore.shared

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("You're all set.")
                    .font(.largeTitle.weight(.bold))

                if let hostname = prefs.fullyQualifiedHostname {
                    Text("Your Mac is reachable at \(hostname)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if let sshCmd = prefs.sshCommand {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Run this command from any device:")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(sshCmd)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(sshCmd, forType: .string)
                            copyConfirmed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copyConfirmed = false
                            }
                        } label: {
                            Image(systemName: copyConfirmed ? "checkmark" : "doc.on.doc")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy SSH command")
                    }
                }
                .padding(.horizontal, 24)
            }

            Text("Burrow is running in your menu bar. Click the icon to manage your tunnel.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("Open Menu Bar") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Close wizard and return to menu bar")
            .keyboardShortcut(.return)
        }
        .padding(40)
    }
}
