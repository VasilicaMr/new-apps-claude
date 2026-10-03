#!/usr/bin/env swift
import AppKit
import CoreGraphics

// 1024x1024 — deep navy-to-purple gradient, waveform bars, three category dots
let size = 1024
let outputPath = "UniversalCap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

guard let ctx = CGContext(
    data: nil,
    width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { print("❌ Failed to create context"); exit(1) }

// ── Background gradient (y=0 is bottom in CGContext) ──────────────────────────
let gradColors = [
    CGColor(red: 0.07, green: 0.04, blue: 0.22, alpha: 1), // deep navy (top-left)
    CGColor(red: 0.28, green: 0.16, blue: 0.58, alpha: 1), // rich purple (bottom-right)
] as CFArray

guard let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: gradColors, locations: [0, 1]
) else { exit(1) }

ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: CGFloat(size)),   // top-left
    end:   CGPoint(x: CGFloat(size), y: 0),   // bottom-right
    options: []
)

// ── Waveform bars ─────────────────────────────────────────────────────────────
// 9 bars, natural waveform shape, rounded caps, slightly above center
let barWidth:    CGFloat = 46
let barSpacing:  CGFloat = 20
let barHeights:  [CGFloat] = [160, 300, 220, 460, 560, 460, 220, 300, 160]
let totalBarsW = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * barSpacing
let barsStartX = (CGFloat(size) - totalBarsW) / 2
let barsCenterY: CGFloat = 580   // shifted up to leave room for dots below

ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))

for (i, h) in barHeights.enumerated() {
    let x = barsStartX + CGFloat(i) * (barWidth + barSpacing)
    let y = barsCenterY - h / 2
    let rect = CGRect(x: x, y: y, width: barWidth, height: h)
    let path = CGPath(roundedRect: rect,
                      cornerWidth: barWidth / 2,
                      cornerHeight: barWidth / 2,
                      transform: nil)
    ctx.addPath(path)
    ctx.fillPath()
}

// ── Three category dots ───────────────────────────────────────────────────────
// purple = thought, green = expense, blue = task
let dotColors: [CGColor] = [
    CGColor(red: 0.67, green: 0.40, blue: 0.93, alpha: 1),
    CGColor(red: 0.20, green: 0.76, blue: 0.56, alpha: 1),
    CGColor(red: 0.22, green: 0.65, blue: 0.96, alpha: 1),
]
let dotDiameter: CGFloat = 58
let dotGap:      CGFloat = 38
let dotsWidth    = 3 * dotDiameter + 2 * dotGap
var dotX         = (CGFloat(size) - dotsWidth) / 2
let dotY:        CGFloat = 130   // from bottom

for color in dotColors {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotDiameter, height: dotDiameter))
    dotX += dotDiameter + dotGap
}

// ── Save PNG ──────────────────────────────────────────────────────────────────
guard let cgImage = ctx.makeImage() else { print("❌ Failed to make image"); exit(1) }

let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
guard let tiff = nsImage.tiffRepresentation,
      let rep  = NSBitmapImageRep(data: tiff),
      let png  = rep.representation(using: .png, properties: [:]) else {
    print("❌ Failed to encode PNG"); exit(1)
}

do {
    let url = URL(fileURLWithPath: outputPath)
    try png.write(to: url)
    print("✅ Icon saved → \(outputPath)")
} catch {
    print("❌ Write failed: \(error)")
    exit(1)
}
