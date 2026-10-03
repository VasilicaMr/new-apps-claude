#if os(iOS)
import UIKit
/// The platform-native color/image types the render pipeline draws with.
/// Everything above this typealias (Data-layer overlays, Presentation
/// thumbnails) is written once and compiles on both iOS and macOS.
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage

extension NSImage {
    /// Mirrors `UIImage.cgImage` so shared code can read `.cgImage` on either platform.
    var cgImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }

    /// Mirrors `UIImage(cgImage:)`; `.zero` tells AppKit to adopt the CGImage's own pixel size.
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
}
#endif

extension PlatformColor {
    /// Creates a color from a "#RRGGBB" or "#RRGGBBAA" hex string. Falls back to black.
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)

        let r, g, b, a: CGFloat
        switch s.count {
        case 8:
            r = CGFloat((value & 0xFF00_0000) >> 24) / 255
            g = CGFloat((value & 0x00FF_0000) >> 16) / 255
            b = CGFloat((value & 0x0000_FF00) >> 8) / 255
            a = CGFloat(value & 0x0000_00FF) / 255
        case 6:
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
