// DocsDeepLink.swift
// Burrow — NSWorkspace helpers for opening external URLs.

import AppKit

enum DocsDeepLink {
    static func openDocs() {
        NSWorkspace.shared.open(URL(string: "https://burrow.hack.ski/docs")!)
    }
}
