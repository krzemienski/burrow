// SubdomainStep.swift  — Phase 6
// TextField + live FQDN preview "<subdomain>.<zone>". Default "m4".

import SwiftUI

struct SubdomainStep: View {

    @Binding var subdomain: String
    let zone: Zone?
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Your Hostname")
                .font(.title2.weight(.semibold))

            Text("Pick a subdomain for your tunnel. This becomes the hostname you SSH into.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Subdomain")
                    .font(.callout)

                TextField("m4", text: $subdomain)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                    .accessibilityLabel("Subdomain for your tunnel hostname")
            }

            LabeledContent("Your SSH hostname:") {
                if let fqdn = computedFQDN {
                    Text(fqdn)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            if let fqdn = computedFQDN {
                Text("You will connect with: ssh \(NSUserName())@\(fqdn)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(subdomain.isEmpty || zone == nil)
                .accessibilityLabel("Continue to cloudflared check")
                .keyboardShortcut(.return)
            }
        }
        .padding(32)
    }

    private var computedFQDN: String? {
        guard !subdomain.isEmpty, let z = zone else { return nil }
        return "\(subdomain).\(z.name)"
    }
}
