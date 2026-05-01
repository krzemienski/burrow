// SettingsView.swift
// Burrow — root tab container for the Settings scene.
//
// PRP §FR-5: five tabs — General, Cloudflare, Tunnel, DNS, Advanced.

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            CloudflareTab()
                .tabItem { Label("Cloudflare", systemImage: "cloud") }

            TunnelTab()
                .tabItem { Label("Tunnel", systemImage: "network") }

            DNSTab()
                .tabItem { Label("DNS", systemImage: "globe") }

            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
