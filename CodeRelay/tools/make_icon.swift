// Renders the CodeRelay app icon (1024×1024 PNG, no alpha channel).
// Usage: swiftc tools/make_icon.swift -o /tmp/make_icon && /tmp/make_icon out.png
import AppKit
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let side = CGFloat(size)
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

let colors = [CGColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1),
              CGColor(red: 0.02, green: 0.03, blue: 0.04, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side), end: CGPoint(x: side, y: 0), options: [])

let mint = NSColor(red: 0.36, green: 0.95, blue: 0.71, alpha: 1)
ctx.setShadow(offset: .zero, blur: 70, color: mint.withAlphaComponent(0.6).cgColor)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let glyph = NSAttributedString(string: "❯_", attributes: [
    .font: NSFont.monospacedSystemFont(ofSize: 400, weight: .heavy),
    .foregroundColor: mint,
    .paragraphStyle: paragraph
])
let height = glyph.size().height
glyph.draw(in: NSRect(x: 0, y: (side - height) / 2, width: side, height: height))
NSGraphicsContext.restoreGraphicsState()

let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
CGImageDestinationFinalize(destination)
