// TokenStep.swift  — Phase 6
// SecureField + deep link to dash.cloudflare.com/profile/api-tokens.
// Lists the 4 required scopes verbatim with copy buttons.

import SwiftUI
import AppKit

struct TokenStep: View {

    @Binding var token: String
    @Binding var email: String     // empty => bearer; non-empty => Global API Key (legacy)
    var onVerified: () -> Void

    @State private var verifyState: TokenVerifyState = .idle

    enum TokenVerifyState {
        case idle
        case checking
        case valid
        case invalid(String)
        case scopeError([String])
    }

    private let requiredScopes = [
        "Account → Cloudflare Tunnel → Edit",
        "Zone    → DNS               → Edit",
        "Zone    → Zone              → Read",
        "Account → Account Settings  → Read"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cloudflare API Token")
                .font(.title2.weight(.semibold))

            Text("Create a token at dash.cloudflare.com/profile/api-tokens with these four permissions:")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(requiredScopes, id: \.self) { scope in
                    HStack {
                        Text(scope)
                            .font(.system(.footnote, design: .monospaced))
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(scope, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy scope: \(scope)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Button("Open Token Dashboard →") {
                NSWorkspace.shared.open(URL(string: "https://dash.cloudflare.com/profile/api-tokens")!)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Open Cloudflare API token creation page")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste your API key or bearer token:")
                    .font(.callout)

                Text("Leave email blank for a scoped Bearer token. Fill email for a Global API Key (legacy auth, all scopes).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Email (only for Global API Key)", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .accessibilityLabel("Cloudflare account email (legacy auth only)")

                HStack {
                    SecureField("API key or bearer token", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Cloudflare API token input")

                    Button("Verify") {
                        verifyToken()
                    }
                    .accessibilityLabel("Verify the API token")
                    .disabled(token.isEmpty || isChecking)
                }

                verifyStatusView
            }

            Spacer()

            HStack {
                Spacer()
                Button("Continue") {
                    onVerified()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValid)
                .accessibilityLabel("Continue to next setup step")
                .keyboardShortcut(.return)
            }
        }
        .padding(32)
    }

    // MARK: - Computed

    private var isChecking: Bool {
        if case .checking = verifyState { return true }
        return false
    }

    private var isValid: Bool {
        if case .valid = verifyState { return true }
        return false
    }

    @ViewBuilder
    private var verifyStatusView: some View {
        switch verifyState {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Verifying…").font(.caption).foregroundStyle(.secondary)
            }
        case .valid:
            Label("Token verified", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .invalid(let reason):
            Label("Invalid: \(reason)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .scopeError(let missing):
            VStack(alignment: .leading, spacing: 4) {
                Label("Missing scopes:", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                ForEach(missing, id: \.self) { scope in
                    Text("  • \(scope)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Verify

    private func verifyToken() {
        verifyState = .checking
        Task {
            do {
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                let auth: CloudflareAuth = trimmedEmail.isEmpty
                    ? .bearer(token: token)
                    : .legacy(email: trimmedEmail, apiKey: token)
                let client = CloudflareClient(auth: auth)
                let result = try await client.verifyToken()
                await MainActor.run {
                    verifyState = result.status == "active" ? .valid : .invalid("status: \(result.status)")
                }
            } catch CloudflareError.invalidToken {
                await MainActor.run { verifyState = .invalid("invalid token") }
            } catch CloudflareError.insufficientScope(let missing) {
                await MainActor.run { verifyState = .scopeError(missing) }
            } catch {
                await MainActor.run { verifyState = .invalid(error.localizedDescription) }
            }
        }
    }
}
