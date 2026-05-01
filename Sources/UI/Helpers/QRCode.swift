// QRCode.swift
// Burrow — QR code generator using CIQRCodeGenerator.
//
// Brand: orange foreground on bean-1 background per BRAND.md §3.

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

enum QRCode {

    /// Generates a QR code for the given string, tinted in brand colors.
    /// Returns nil if generation fails (empty string, CI filter error).
    static func make(string: String, size: CGSize) -> Image? {
        guard !string.isEmpty else { return nil }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale to requested size
        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Brand tint: cyber orange foreground on bean-1 background.
        // CIFalseColor maps the QR's black to color0 and white to color1.
        let tintFilter = CIFilter.falseColor()
        tintFilter.inputImage = scaled
        tintFilter.color0 = CIColor(red: 0xFF/255.0, green: 0x6A/255.0, blue: 0x1A/255.0) // --orange
        tintFilter.color1 = CIColor(red: 0x0E/255.0, green: 0x09/255.0, blue: 0x07/255.0) // --bean-1

        guard let tinted = tintFilter.outputImage,
              let cgImage = context.createCGImage(tinted, from: tinted.extent) else {
            return nil
        }

        let nsImage = NSImage(cgImage: cgImage, size: size)
        return Image(nsImage: nsImage)
    }
}
