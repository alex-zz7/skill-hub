#!/usr/bin/env swift
// Renders the app icon: a soft indigo→teal squircle with three clustered bubbles.
// Usage: swift scripts/make-icon.swift  (writes into SkillHub/Resources/Assets.xcassets/AppIcon.appiconset)

import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDir = projectRoot.appendingPathComponent("SkillHub/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func draw(in size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }
    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // macOS icon grid: artwork sits inside ~82% of the canvas with a 22.4% corner radius.
    let inset = size * 0.09
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.224
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.03, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    NSColor(srgbRed: 0.35, green: 0.38, blue: 0.94, alpha: 1).setFill()
    squircle.fill()
    context.restoreGState()

    squircle.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.33, green: 0.34, blue: 0.95, alpha: 1),
        NSColor(srgbRed: 0.22, green: 0.62, blue: 0.86, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.74, blue: 0.70, alpha: 1)
    ])!
    gradient.draw(in: rect, angle: -60)

    // Faint inner highlight along the top edge so the surface reads as a material.
    let highlight = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    highlight.draw(in: rect, angle: -90)

    func bubble(cx: CGFloat, cy: CGFloat, r: CGFloat, alpha: CGFloat) {
        let circle = NSBezierPath(ovalIn: CGRect(x: rect.minX + rect.width * cx - r, y: rect.minY + rect.height * cy - r, width: r * 2, height: r * 2))
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -r * 0.12), blur: r * 0.35, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        NSColor.white.withAlphaComponent(alpha).setFill()
        circle.fill()
        context.restoreGState()
        NSColor.white.withAlphaComponent(0.55).setStroke()
        circle.lineWidth = max(1, r * 0.04)
        circle.stroke()
    }

    let unit = rect.width
    bubble(cx: 0.38, cy: 0.58, r: unit * 0.21, alpha: 0.96)
    bubble(cx: 0.68, cy: 0.66, r: unit * 0.13, alpha: 0.92)
    bubble(cx: 0.62, cy: 0.33, r: unit * 0.165, alpha: 0.94)

    // Nucleus dot linking the cluster.
    let nucleus = NSBezierPath(ovalIn: CGRect(x: rect.midX - unit * 0.035, y: rect.midY - unit * 0.035, width: unit * 0.07, height: unit * 0.07))
    NSColor(srgbRed: 0.13, green: 0.16, blue: 0.45, alpha: 0.9).setFill()
    nucleus.fill()

    return image
}

func png(from image: NSImage, pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let master = draw(in: 1024)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in sizes {
    let source = pixels <= 64 ? draw(in: CGFloat(pixels)) : master
    guard let data = png(from: source, pixels: pixels) else {
        FileHandle.standardError.write("failed to render \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    try data.write(to: outputDir.appendingPathComponent(name))
    print("wrote \(name)")
}
