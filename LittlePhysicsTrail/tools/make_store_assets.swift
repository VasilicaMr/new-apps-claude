#!/usr/bin/env swift
//
//  make_store_assets.swift
//  LittlePhysicsTrail
//
//  Renders the App Store Connect "Header and Search Results" creative assets (iOS 27):
//    header.png          3840 × 1646 (21:9)  — illustrated trail, no text (works in every language)
//    search_results.png  3840 × 2560 (3:2)   — headline + the real game screen
//  Both are opaque PNGs (App Store Connect rejects alpha). Key content stays inside the
//  safe areas from Apple's templates (see AppStoreAssets/README.md).
//
//  Usage: swift tools/make_store_assets.swift <game-screenshot.png> <output-dir>
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Palette (mirrors Presentation/DesignSystem/NubeeTheme.swift, light mode)

enum Palette {
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.30)
    static let inkSoft = Color(red: 0.40, green: 0.40, blue: 0.55)
    static let sun = Color(red: 1.00, green: 0.82, blue: 0.22)
    static let sky = Color(red: 0.30, green: 0.62, blue: 1.00)
    static let pink = Color(red: 0.96, green: 0.40, blue: 0.66)
    static let coral = Color(red: 1.00, green: 0.47, blue: 0.36)
    static let orange = Color(red: 1.00, green: 0.66, blue: 0.16)
    static let gold = Color(red: 0.95, green: 0.68, blue: 0.05)
    static let teal = Color(red: 0.12, green: 0.70, blue: 0.80)
    static let mint = Color(red: 0.20, green: 0.80, blue: 0.56)
    static let purple = Color(red: 0.45, green: 0.36, blue: 0.96)
    static let road = Color.white.opacity(0.92)
}

struct Background: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 1.00, green: 0.96, blue: 0.88), Color(red: 0.86, green: 0.94, blue: 1.00)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Palette.sun.opacity(0.30)).frame(width: w * 0.45).blur(radius: 120)
                    .position(x: w * 0.08, y: h * 0.1)
                Circle().fill(Palette.sky.opacity(0.24)).frame(width: w * 0.5).blur(radius: 140)
                    .position(x: w * 0.95, y: h * 0.95)
                Circle().fill(Palette.pink.opacity(0.14)).frame(width: w * 0.3).blur(radius: 110)
                    .position(x: w * 0.85, y: h * 0.12)
            }
        }
    }
}

// MARK: - Header (3840 × 1646)

struct TrailStop: View {
    let emoji: String
    let color: Color
    var size: CGFloat = 380
    var highlighted = false

    var body: some View {
        ZStack {
            if highlighted {
                Circle().stroke(color.opacity(0.35), lineWidth: 26).frame(width: size * 1.3, height: size * 1.3)
            }
            Circle().fill(Color.white).shadow(color: color.opacity(0.35), radius: 40, y: 22)
            Circle().strokeBorder(color, lineWidth: size * 0.085)
            Text(emoji).font(.system(size: size * 0.44))
        }
        .frame(width: size, height: size)
    }
}

struct Header: View {
    static let size = CGSize(width: 3840, height: 1646)

    // Seven stops snake across; the middle one (💡, highlighted) sits in the safe area with the owl.
    private let stops: [(String, Color)] = [
        ("🛁", Palette.sky), ("🧲", Palette.coral), ("💪", Palette.orange), ("💡", Palette.gold),
        ("🌡️", Palette.pink), ("🔊", Palette.teal), ("🧪", Palette.purple),
    ]
    private func point(_ i: Int) -> CGPoint {
        CGPoint(x: 160 + CGFloat(i) * 585, y: i.isMultiple(of: 2) ? 1060 : 640)
    }

    private let floaters: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
        // emoji, x, y, size, rotation
        ("🦆", 470, 300, 150, -10), ("⚓️", 760, 1330, 130, 8), ("📎", 1080, 420, 120, 14),
        ("⚽️", 1310, 1380, 140, -6), ("🪁", 1640, 330, 150, 10), ("🌙", 2330, 1390, 140, -12),
        ("🧊", 2780, 340, 130, 8), ("🥁", 2820, 1380, 140, -8), ("🎈", 3360, 300, 150, 6),
        ("🫧", 3420, 1400, 130, 0), ("⭐️", 2050, 250, 100, 12), ("🍎", 120, 1430, 130, -8),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Background()

            // Color bands so the trail feels like it moves through places.
            ForEach(stops.indices, id: \.self) { i in
                Ellipse().fill(stops[i].1.opacity(0.16)).frame(width: 900, height: 900).blur(radius: 120)
                    .position(point(i))
            }

            road
            ForEach(floaters.indices, id: \.self) { i in
                let f = floaters[i]
                Text(f.0).font(.system(size: f.3)).rotationEffect(.degrees(f.4)).opacity(0.9)
                    .position(x: f.1, y: f.2)
            }
            ForEach(stops.indices, id: \.self) { i in
                TrailStop(emoji: stops[i].0, color: stops[i].1, highlighted: i == 3)
                    .position(point(i))
            }

            // The owl guide next to the highlighted stop (inside the safe area).
            Text("🦉").font(.system(size: 230))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 12)
                .position(x: 2020, y: 1110)
            Text("✨").font(.system(size: 110)).position(x: 1770, y: 1010)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    private var road: some View {
        let points = [CGPoint(x: -300, y: 640)] + stops.indices.map(point) + [CGPoint(x: 4300, y: 640)]
        let path = Path { p in
            p.move(to: points[0])
            for (a, b) in zip(points, points.dropFirst()) {
                let dx = b.x - a.x
                p.addCurve(to: b, control1: CGPoint(x: a.x + dx * 0.5, y: a.y), control2: CGPoint(x: b.x - dx * 0.5, y: b.y))
            }
        }
        return ZStack {
            path.stroke(Palette.road, style: StrokeStyle(lineWidth: 110, lineCap: .round))
                .shadow(color: .black.opacity(0.07), radius: 24, y: 12)
            path.stroke(Palette.inkSoft.opacity(0.28), style: StrokeStyle(lineWidth: 18, lineCap: .round, dash: [6, 52]))
        }
    }
}

// MARK: - Search results (3840 × 2560)

struct SearchResults: View {
    static let size = CGSize(width: 3840, height: 2560)
    let screenshot: NSImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            Background()

            // Headline: left, inside the safe area (x 836–3004, y 765–1795).
            VStack(alignment: .leading, spacing: 60) {
                Text("Sort it.\nLearn why.")
                    .font(.system(size: 220, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(-10)
                Text("8 big physics ideas\nfor curious kids")
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 22) {
                    ForEach(["🛁", "🧲", "💪", "💡", "🌡️", "🔊"], id: \.self) { e in
                        Text(e).font(.system(size: 92))
                            .frame(width: 150, height: 150)
                            .background(Color.white.opacity(0.9), in: Circle())
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                    }
                }
            }
            .frame(width: 1300, alignment: .leading)
            .position(x: 836 + 650, y: 1290)

            phone
                .rotationEffect(.degrees(4))
                .position(x: 2150 + 880, y: 470 + 1700)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    /// The real game screen in a simple generic phone frame; it runs off the bottom edge on purpose.
    private var phone: some View {
        let screenWidth: CGFloat = 1640
        let screenHeight = screenWidth * screenshot.size.height / screenshot.size.width
        return Image(nsImage: screenshot)
            .resizable()
            .frame(width: screenWidth, height: screenHeight)
            .clipShape(RoundedRectangle(cornerRadius: 170, style: .continuous))
            .padding(44)
            .background(Color(red: 0.11, green: 0.11, blue: 0.16), in: RoundedRectangle(cornerRadius: 214, style: .continuous))
            .shadow(color: Palette.ink.opacity(0.25), radius: 80, y: 40)
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
    ctx.setFillColor(.white)
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
guard args.count == 3, let screenshot = NSImage(contentsOfFile: args[1]) else {
    print("usage: swift tools/make_store_assets.swift <game-screenshot.png> <output-dir>")
    exit(1)
}
let out = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

try MainActor.assumeIsolated {
    try render(Header(), size: Header.size, to: out.appendingPathComponent("header.png"))
    try render(SearchResults(screenshot: screenshot), size: SearchResults.size, to: out.appendingPathComponent("search_results.png"))
}
