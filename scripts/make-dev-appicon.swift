#!/usr/bin/env swift

// Builds AppIconDev.appiconset from AppIcon.appiconset by laying a DEV band
// across the bottom of every rendition. Run it again whenever the real icon
// changes; the dev icon is derived art, not something to hand-edit.
//
//   swift scripts/make-dev-appicon.swift

import AppKit
import Foundation

let assets = URL(fileURLWithPath: "MonMon/Resources/Assets.xcassets")
let source = assets.appendingPathComponent("AppIcon.appiconset")
let destination = assets.appendingPathComponent("AppIconDev.appiconset")

let bandColor = NSColor(srgbRed: 0.85, green: 0.16, blue: 0.13, alpha: 0.94)
let bandFraction: CGFloat = 0.30

func badged(_ url: URL) throws -> Data {
    guard
        let image = NSImage(contentsOf: url),
        let tiff = image.tiffRepresentation,
        let measured = NSBitmapImageRep(data: tiff)
    else {
        throw CocoaError(.fileReadCorruptFile)
    }

    let width = measured.pixelsWide
    let height = measured.pixelsHigh
    guard
        let canvas = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    canvas.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)

    let bounds = NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)

    let bandHeight = bounds.height * bandFraction
    bandColor.setFill()
    NSRect(x: 0, y: 0, width: bounds.width, height: bandHeight).fill()

    // Below roughly 32 points the glyphs turn to mush, and a smear of red still
    // tells the two icons apart in a Spotlight row. The band alone carries it.
    if bounds.height >= 32 {
        let pointSize = bandHeight * 0.62
        let label = NSAttributedString(
            string: "DEV",
            attributes: [
                .font: NSFont.systemFont(ofSize: pointSize, weight: .heavy),
                .foregroundColor: NSColor.white,
                .kern: pointSize * 0.08,
            ]
        )
        let measuredLabel = label.size()
        label.draw(
            at: NSPoint(
                x: (bounds.width - measuredLabel.width) / 2,
                y: (bandHeight - measuredLabel.height) / 2
            )
        )
    }

    guard let png = canvas.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

let manager = FileManager.default
try? manager.removeItem(at: destination)
try manager.createDirectory(at: destination, withIntermediateDirectories: true)

let entries = try manager.contentsOfDirectory(atPath: source.path).sorted()
var written = 0
for entry in entries where entry.hasSuffix(".png") {
    let renamed = entry.replacingOccurrences(of: "AppIcon-", with: "AppIconDev-")
    try badged(source.appendingPathComponent(entry))
        .write(to: destination.appendingPathComponent(renamed))
    written += 1
}

let manifest = try String(
    contentsOf: source.appendingPathComponent("Contents.json"),
    encoding: .utf8
)
try manifest
    .replacingOccurrences(of: "AppIcon-", with: "AppIconDev-")
    .write(
        to: destination.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )

print("wrote \(written) renditions to \(destination.path)")
