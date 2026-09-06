#!/usr/bin/env swift
// Turns a raw window capture into a Mac App Store screenshot (2880×1800):
// gradient background, headline + subline, window with shadow peeking from the bottom.
//
//   swift scripts/compose-screenshot.swift <input.png> <output.png> "<headline>" "<subline>" [hue 0-1]

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 5 else {
    FileHandle.standardError.write("usage: compose-screenshot.swift input output headline subline [hue]\n".data(using: .utf8)!)
    exit(2)
}
let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let headline = args[3]
let subline = args[4]
let hue = args.count > 5 ? CGFloat(Double(args[5]) ?? 0.62) : 0.62

guard let window = NSImage(contentsOf: inputURL), let windowRep = window.representations.first else {
    FileHandle.standardError.write("cannot read \(inputURL.path)\n".data(using: .utf8)!)
    exit(1)
}

let canvasW: CGFloat = 2880, canvasH: CGFloat = 1800
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvasW), pixelsHigh: Int(canvasH), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }
rep.size = NSSize(width: canvasW, height: canvasH)

NSGraphicsContext.saveGraphicsState()
let gc = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gc
gc.imageInterpolation = .high
let ctx = gc.cgContext
let canvas = CGRect(x: 0, y: 0, width: canvasW, height: canvasH)

// Background: soft two-tone gradient with a lighter wash near the top so the headline stays legible.
let c1 = NSColor(hue: hue, saturation: 0.55, brightness: 0.96, alpha: 1)
let c2 = NSColor(hue: hue + 0.08, saturation: 0.45, brightness: 0.82, alpha: 1)
NSGradient(colors: [c1, c2])!.draw(in: canvas, angle: -70)
NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
    .draw(in: CGRect(x: 0, y: canvasH - 700, width: canvasW, height: 700), angle: -90)

// Text block (AppKit coordinates: origin bottom-left).
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let headAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 104, weight: .bold),
    .foregroundColor: NSColor(white: 0.08, alpha: 1),
    .paragraphStyle: paragraph,
    .kern: -1.5
]
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 44, weight: .medium),
    .foregroundColor: NSColor(white: 0.08, alpha: 0.72),
    .paragraphStyle: paragraph
]
let headRect = CGRect(x: 160, y: canvasH - 150 - 130, width: canvasW - 320, height: 130)
NSAttributedString(string: headline, attributes: headAttrs).draw(in: headRect)
let subRect = CGRect(x: 240, y: headRect.minY - 24 - 60, width: canvasW - 480, height: 60)
NSAttributedString(string: subline, attributes: subAttrs).draw(in: subRect)

// Window: scale to 2480 wide, anchor at the bottom so it "peeks" up from the edge.
let pixelW = CGFloat(windowRep.pixelsWide)
let pixelH = CGFloat(windowRep.pixelsHigh)
let targetW: CGFloat = 2480
let scale = targetW / pixelW
let targetH = pixelH * scale
let windowRect = CGRect(x: (canvasW - targetW) / 2, y: -40, width: targetW, height: targetH)
let visibleTop = subRect.minY - 70
let clipHeight = min(targetH, visibleTop - windowRect.minY)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60, color: NSColor.black.withAlphaComponent(0.28).cgColor)
let radius: CGFloat = 26
let path = NSBezierPath(roundedRect: CGRect(x: windowRect.minX, y: windowRect.minY, width: targetW, height: clipHeight), xRadius: radius, yRadius: radius)
NSColor.white.setFill()
path.fill()
ctx.restoreGState()

ctx.saveGState()
path.addClip()
// Draw the top `clipHeight` of the window image aligned with the clip's top edge.
let srcHeightPoints = clipHeight / scale
let fromRect = NSRect(x: 0, y: pixelH - srcHeightPoints, width: pixelW, height: srcHeightPoints)
window.draw(
    in: CGRect(x: windowRect.minX, y: windowRect.minY, width: targetW, height: clipHeight),
    from: NSRect(x: fromRect.minX * window.size.width / pixelW, y: fromRect.minY * window.size.height / pixelH,
                 width: window.size.width, height: fromRect.height * window.size.height / pixelH),
    operation: .sourceOver, fraction: 1
)
ctx.restoreGState()
NSColor.black.withAlphaComponent(0.12).setStroke()
path.lineWidth = 2
path.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: outputURL)
print("wrote \(outputURL.lastPathComponent) (\(Int(canvasW))x\(Int(canvasH)))")
