// WelcomeStep.swift  — Phase 6
// H2 explanation, tagline, Continue button.

import SwiftUI

struct WelcomeStep: View {

    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "network")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Welcome to Burrow")
                    .font(.largeTitle.weight(.bold))

                Text("Your machine, teleported.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "lock.shield",
                           text: "One Cloudflare API token — stored securely in Keychain, never on disk.")
                featureRow(icon: "terminal",
                           text: "SSH to your Mac from anywhere with a stable hostname like m4.yourdomain.com.")
                featureRow(icon: "arrow.triangle.2.circlepath",
                           text: "Survives sleep, wake, and WiFi switches automatically.")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Begin Burrow setup wizard")
            .keyboardShortcut(.return)
        }
        .padding(40)
    }

    @ViewBuilder
    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}
