#!/usr/bin/env swift
//
//  make_store_assets.swift
//  ScoreCap
//
//  Renders the App Store "Header and Search Results" artwork (iOS 27):
//    header.png                   3840 × 1646 (21:9)  the +1 button among the sport categories, no text
//    <locale>/search_results.png  3840 × 2560 (3:2)   headline plus the real Home screen
//  Both are opaque PNGs (App Store Connect rejects alpha) and keep key content inside the safe areas from
//  Apple's templates (see AppStoreAssets/README.md).
//
//  Usage: swift Scripts/make_store_assets.swift AppStoreAssets
//  Reads AppStoreAssets/Source/home_<lang>.png (a 6.9" iPhone screenshot of Home).
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Palette (the app icon, plus Color.forSportCategory)

enum Palette {
    static let navyTop = Color(red: 0.12, green: 0.17, blue: 0.31)
    static let navyBottom = Color(red: 0.05, green: 0.08, blue: 0.15)
    static let green = Color(red: 0.20, green: 0.78, blue: 0.42)
    static let greenLight = Color(red: 0.38, green: 0.86, blue: 0.56)
    static let greenDark = Color(red: 0.13, green: 0.66, blue: 0.34)
    static let text = Color.white
    static let textSoft = Color.white.opacity(0.68)

    /// One per `SportCategory`, in the app's order, with its symbol.
    static let categories: [(symbol: String, color: Color)] = [
        ("target", .orange), ("circle.grid.3x3.fill", .green), ("figure.bowling", .blue), ("figure.tennis", .yellow),
        ("suit.spade.fill", .purple), ("crown.fill", .indigo), ("snowflake", .cyan), ("arcade.stick", .pink),
    ]
}

struct Background: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Palette.navyTop, Palette.navyBottom], startPoint: .top, endPoint: .bottom)
                Circle().fill(Palette.green.opacity(0.16)).frame(width: w * 0.42).blur(radius: 180)
                    .position(x: w * 0.5, y: h * 0.52)
                Circle().fill(Color.blue.opacity(0.14)).frame(width: w * 0.4).blur(radius: 180)
                    .position(x: w * 0.05, y: h * 0.95)
                Circle().fill(Color.purple.opacity(0.12)).frame(width: w * 0.35).blur(radius: 160)
                    .position(x: w * 0.97, y: h * 0.1)
            }
        }
    }
}

/// A sport category tile: the category color as a gradient with a white symbol.
struct Tile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 300

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.95), color.mix(with: .black, by: 0.25)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: size * 0.018))
                .shadow(color: .black.opacity(0.35), radius: size * 0.12, y: size * 0.07)
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// The app icon's green "+1" button with its rings.
struct PlusOne: View {
    var size: CGFloat = 640
    var rings = true

    var body: some View {
        ZStack {
            if rings {
                ForEach([1.32, 1.6, 1.92], id: \.self) { scale in
                    Circle().stroke(Palette.green.opacity(0.32 - (scale - 1.32) * 0.3), lineWidth: size * 0.022)
                        .frame(width: size * scale, height: size * scale)
                }
            }
            Circle()
                .fill(LinearGradient(colors: [Palette.greenLight, Palette.green, Palette.greenDark],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    Ellipse().fill(.white.opacity(0.18)).frame(width: size * 0.74, height: size * 0.3)
                        .offset(y: -size * 0.26)
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.45), radius: size * 0.08, y: size * 0.05)
            Text("+1")
                .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: size * 0.02, y: size * 0.01)
                .offset(x: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Header (3840 × 1646)

struct Header: View {
    static let size = CGSize(width: 3840, height: 1646)

    // The eight categories, four on each side of the +1 button, rising toward it.
    private let tiles: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double)] = [
        (230, 1180, 280, -8), (690, 760, 300, 6), (1100, 1230, 290, -5), (1380, 600, 270, 8),
        (2460, 600, 270, -8), (2740, 1230, 290, 5), (3150, 760, 300, -6), (3610, 1180, 280, 8),
    ]

    // Faint score marks; none near the top edge, where the App Store's buttons sit.
    private let floaters: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
        ("+1", 420, 430, 140, -10), ("+3", 940, 520, 120, 8), ("180", 820, 1470, 110, -6), ("+2", 1600, 1380, 130, 10),
        ("15", 1260, 940, 100, -8), ("+1", 2300, 1400, 120, -8), ("147", 2950, 470, 110, 6), ("+5", 2600, 920, 100, 10),
        ("300", 3020, 1480, 110, -4), ("+1", 3420, 430, 140, 10),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Background()
            ForEach(floaters.indices, id: \.self) { i in
                let f = floaters[i]
                Text(f.0).font(.system(size: f.3, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.1))
                    .rotationEffect(.degrees(f.4))
                    .position(x: f.1, y: f.2)
            }
            ForEach(tiles.indices, id: \.self) { i in
                let t = tiles[i], category = Palette.categories[i]
                Tile(symbol: category.symbol, color: category.color, size: t.size)
                    .rotationEffect(.degrees(t.rotation))
                    .position(x: t.x, y: t.y)
            }
            // Centered in the template's safe area (about x 1097–2743, y 493–1154).
            PlusOne(size: 600).position(x: 1920, y: 860)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }
}

// MARK: - Search results (3840 × 2560)

struct Copy {
    let headline: String
    let subline: String
}

/// App Store Connect locale folder → screenshot language and text.
let languages: [(folder: String, lang: String, copy: Copy)] = [
    ("en-US", "en", Copy(headline: "Keep score\nfor any game.",
                         subline: "48 sports and 38 home games.\nTap +1, ScoreCap does the math.")),
]

struct SearchResults: View {
    static let size = CGSize(width: 3840, height: 2560)
    let copy: Copy
    let screenshot: NSImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            Background()

            // Headline: left, inside the safe area (x 836–3004, y 765–1795).
            VStack(alignment: .leading, spacing: 64) {
                Text(copy.headline)
                    .font(.system(size: 210, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .lineSpacing(-8)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Text(copy.subline)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSoft)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                HStack(spacing: 26) {
                    ForEach(Palette.categories.prefix(5).indices, id: \.self) { i in
                        Tile(symbol: Palette.categories[i].symbol, color: Palette.categories[i].color, size: 150)
                    }
                }
            }
            .frame(width: 1450, alignment: .leading)
            .position(x: 836 + 725, y: 1290)

            phone
                .rotationEffect(.degrees(4))
                .position(x: 2250 + 880, y: 470 + 1700)

            PlusOne(size: 380, rings: false)
                .position(x: 2330, y: 1980)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    /// The real Home screen in a simple generic phone frame; it runs off the bottom edge on purpose.
    private var phone: some View {
        let screenWidth: CGFloat = 1500
        let screenHeight = screenWidth * screenshot.size.height / screenshot.size.width
        return Image(nsImage: screenshot)
            .resizable()
            .frame(width: screenWidth, height: screenHeight)
            .clipShape(RoundedRectangle(cornerRadius: 160, style: .continuous))
            .padding(42)
            .background(Color(red: 0.02, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 200, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 200, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 6))
            .shadow(color: .black.opacity(0.5), radius: 80, y: 40)
    }
}

// MARK: - Rendering

@MainActor
func render<V: View>(_ view: V, size: CGSize, to url: URL) throws {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 1
    guard let image = renderer.cgImage else { throw NSError(domain: "render", code: 1) }

    // Flatten onto an opaque bitmap: App Store Connect rejects images with an alpha channel.
    guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw NSError(domain: "render", code: 2) }
    ctx.setFillColor(.black)
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.draw(image, in: CGRect(origin: .zero, size: size))

    guard let flat = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "render", code: 3) }
    CGImageDestinationAddImage(dest, flat, nil)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "render", code: 4) }
    print("wrote \(url.path) (\(Int(size.width))×\(Int(size.height)))")
}

let args = CommandLine.arguments
guard args.count == 2 else {
    print("usage: swift Scripts/make_store_assets.swift <AppStoreAssets dir>")
    exit(1)
}
let out = URL(fileURLWithPath: args[1], isDirectory: true)

try MainActor.assumeIsolated {
    try render(Header(), size: Header.size, to: out.appendingPathComponent("header.png"))
    for language in languages {
        let source = out.appendingPathComponent("Source/home_\(language.lang).png")
        guard let screenshot = NSImage(contentsOf: source) else {
            print("missing \(source.path), skipped \(language.folder)")
            continue
        }
        let folder = out.appendingPathComponent(language.folder, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try render(SearchResults(copy: language.copy, screenshot: screenshot), size: SearchResults.size,
                   to: folder.appendingPathComponent("search_results.png"))
    }
}
