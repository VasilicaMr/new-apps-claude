#!/usr/bin/env swift
//
//  make_store_assets.swift
//  FleetCheck
//
//  Renders the App Store artwork:
//    header.png                   3840 × 1646 (21:9)  "Header and Search Results" (iOS 27): a road with the app's jobs, no text
//    <locale>/search_results.png  3840 × 2560 (3:2)   headline plus the real Home screen, one per language
//    <locale>/iphone/*.png        1320 × 2868         App Store screenshots (6.9" iPhone) with a caption
//    <locale>/ipad/*.png          2064 × 2752         App Store screenshots (13" iPad) with a caption
//  All are opaque PNGs (App Store Connect rejects alpha). Header and search results keep key content inside
//  the safe areas from Apple's templates (see AppStoreAssets/README.md).
//
//  Usage: swift Scripts/make_store_assets.swift AppStoreAssets
//  Reads AppStoreAssets/Source/home_<lang>.png and Source/screens/<device>/<lang>/<n>_<screen>.png,
//  both from Scripts/capture_store_screenshots.sh.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Palette (mirrors Presentation/DesignSystem/Theme.swift, light mode)

enum Palette {
    static let ink = Color(red: 0.14, green: 0.20, blue: 0.32)
    static let inkSoft = ink.opacity(0.62)
    static let canvasTop = Color(red: 0.99, green: 0.97, blue: 0.93)
    static let canvasBottom = Color(red: 0.90, green: 0.95, blue: 0.99)
    static let blue = Color(red: 0.35, green: 0.48, blue: 0.95)
    static let warning = Color(red: 0.98, green: 0.62, blue: 0.22)
    static let positive = Color(red: 0.22, green: 0.72, blue: 0.48)

    static func gradient(_ from: (Double, Double, Double), _ to: (Double, Double, Double)) -> LinearGradient {
        LinearGradient(colors: [Color(red: from.0, green: from.1, blue: from.2), Color(red: to.0, green: to.1, blue: to.2)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let shift = gradient((0.38, 0.55, 0.98), (0.55, 0.40, 0.95))
    static let earnings = gradient((1.00, 0.78, 0.36), (1.00, 0.56, 0.32))
    static let receipt = gradient((0.40, 0.82, 0.62), (0.22, 0.58, 0.72))
    static let voice = gradient((0.25, 0.72, 0.82), (0.35, 0.48, 0.95))
    static let week = gradient((1.00, 0.72, 0.38), (0.95, 0.48, 0.42))
    static let car = gradient((0.52, 0.48, 0.68), (0.38, 0.36, 0.52))
    static let profit = gradient((0.22, 0.72, 0.48), (0.18, 0.55, 0.38))
}

struct Background: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Palette.canvasTop, Palette.canvasBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Palette.warning.opacity(0.22)).frame(width: w * 0.45).blur(radius: 140)
                    .position(x: w * 0.08, y: h * 0.12)
                Circle().fill(Palette.blue.opacity(0.18)).frame(width: w * 0.5).blur(radius: 160)
                    .position(x: w * 0.95, y: h * 0.95)
                Circle().fill(Palette.positive.opacity(0.12)).frame(width: w * 0.3).blur(radius: 120)
                    .position(x: w * 0.85, y: h * 0.1)
            }
        }
    }
}

/// The app's gradient tile with a white symbol, as on Home's cards.
struct Tile: View {
    let symbol: String
    let gradient: LinearGradient
    var size: CGFloat = 330
    var highlighted = false

    var body: some View {
        ZStack {
            if highlighted {
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .stroke(Palette.blue.opacity(0.25), lineWidth: 28)
                    .frame(width: size * 1.32, height: size * 1.32)
            }
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(gradient)
                .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 6))
                .shadow(color: Palette.ink.opacity(0.18), radius: 40, y: 22)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Header (3840 × 1646)

struct Header: View {
    static let size = CGSize(width: 3840, height: 1646)

    // A driver's day along the road; the car (highlighted) sits in the middle of the safe area.
    private let stops: [(String, LinearGradient)] = [
        ("clock.fill", Palette.shift), ("text.viewfinder", Palette.earnings), ("fuelpump.fill", Palette.receipt),
        ("car.side.fill", Palette.shift), ("chart.bar.fill", Palette.profit), ("calendar", Palette.week),
        ("sparkles", Palette.voice),
    ]
    private func point(_ i: Int) -> CGPoint {
        CGPoint(x: 160 + CGFloat(i) * 585, y: i.isMultiple(of: 2) ? 1060 : 640)
    }

    private let floaters: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
        // symbol, x, y, size, rotation
        ("mappin.circle.fill", 470, 310, 130, -8), ("speedometer", 760, 1350, 120, 6), ("star.fill", 1080, 400, 90, 14),
        ("flag.checkered", 1320, 1380, 120, -6), ("location.fill", 1640, 330, 110, 10), ("moon.stars.fill", 2330, 1390, 120, -10),
        ("bell.fill", 2780, 330, 110, 8), ("wrench.and.screwdriver.fill", 2830, 1380, 120, -8), ("road.lanes", 3360, 300, 130, 0),
        ("mappin.and.ellipse", 3420, 1400, 120, 0), ("star.fill", 2060, 250, 80, -12), ("sun.max.fill", 120, 1430, 120, 0),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Background()
            road
            ForEach(floaters.indices, id: \.self) { i in
                let f = floaters[i]
                Image(systemName: f.0).font(.system(size: f.3, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.16))
                    .rotationEffect(.degrees(f.4))
                    .position(x: f.1, y: f.2)
            }
            ForEach(stops.indices, id: \.self) { i in
                Tile(symbol: stops[i].0, gradient: stops[i].1, size: i == 3 ? 420 : 330, highlighted: i == 3)
                    .position(point(i))
            }
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
            path.stroke(Palette.ink.opacity(0.82), style: StrokeStyle(lineWidth: 150, lineCap: .round))
                .shadow(color: .black.opacity(0.12), radius: 30, y: 14)
            path.stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 14, lineCap: .butt, dash: [70, 60]))
        }
    }
}

// MARK: - Search results (3840 × 2560)

struct Copy {
    let headline: String
    let subline: String
}

/// App Store Connect locale folder → screenshot language and text.
let languages: [(folder: String, lang: String, copy: Copy)] = [
    ("en-US", "en", Copy(headline: "Know what you\nreally keep.",
                         subline: "Earnings read from a screenshot.\nYour real pay per hour, after costs.")),
    ("ro", "ro", Copy(headline: "Vezi cât îți\nrămâne de fapt.",
                      subline: "Câștigurile citite dintr-o captură.\nCât faci pe oră, după costuri.")),
    ("fr-FR", "fr", Copy(headline: "Voyez ce qu’il\nvous reste vraiment.",
                         subline: "Gains lus depuis une capture.\nVotre vrai gain par heure, après frais.")),
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
                    .font(.system(size: 200, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(-8)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Text(copy.subline)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                HStack(spacing: 26) {
                    Tile(symbol: "text.viewfinder", gradient: Palette.earnings, size: 150)
                    Tile(symbol: "clock.fill", gradient: Palette.shift, size: 150)
                    Tile(symbol: "fuelpump.fill", gradient: Palette.receipt, size: 150)
                    Tile(symbol: "chart.bar.fill", gradient: Palette.profit, size: 150)
                }
            }
            .frame(width: 1400, alignment: .leading)
            .position(x: 836 + 700, y: 1290)

            phone
                .rotationEffect(.degrees(4))
                .position(x: 2250 + 880, y: 470 + 1700)
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
            .background(Color(red: 0.11, green: 0.12, blue: 0.17), in: RoundedRectangle(cornerRadius: 200, style: .continuous))
            .shadow(color: Palette.ink.opacity(0.25), radius: 80, y: 40)
    }
}

// MARK: - Screenshots (iPhone 1320 × 2868, iPad 2064 × 2752)

/// Caption per screen (file name without its number) and language: headline, then subline.
let captions: [String: [String: (String, String)]] = [
    "home": ["en": ("Know what you really keep", "Earnings, costs and net in one place"),
             "ro": ("Vezi cât îți rămâne", "Câștiguri, costuri și net într-un loc"),
             "fr": ("Voyez ce qu’il vous reste", "Gains, frais et net au même endroit")],
    "scan": ["en": ("Earnings read from a screenshot", "No typing: fares, tips, trips and km"),
             "ro": ("Câștiguri citite\ndintr-o captură", "Fără scris: curse, bacșiș și km"),
             "fr": ("Vos gains lus sur une capture", "Rien à taper : courses, pourboires, km")],
    "stats": ["en": ("Your real pay per hour", "Net after costs, per hour and per km"),
              "ro": ("Cât faci de fapt pe oră", "Net după costuri, pe oră și pe km"),
              "fr": ("Votre vrai gain par heure", "Net après frais, par heure et par km")],
    "min_fare": ["en": ("Know your minimum fare", "The true cost of your car per km"),
                 "ro": ("Află tariful tău minim", "Costul real al mașinii pe km"),
                 "fr": ("Connaissez votre tarif minimum", "Le vrai coût de votre voiture au km")],
    "best_times": ["en": ("Drive when it pays best", "Your best days and hours"),
                   "ro": ("Condu când se plătește bine", "Zilele și orele cele mai bune"),
                   "fr": ("Roulez quand ça paie le plus", "Vos meilleurs jours et horaires")],
    "ask": ["en": ("Just ask", "“How much did I make this week?”"),
            "ro": ("Întreabă, pur și simplu", "„Cât am câștigat săptămâna asta?”"),
            "fr": ("Demandez, tout simplement", "« Combien j’ai gagné cette semaine ? »")],
    "car": ["en": ("Car papers on time", "Reminders by date or kilometers"),
            "ro": ("Actele mașinii la timp", "ITP, RCA, rovinietă și schimb de ulei"),
            "fr": ("Papiers de la voiture à jour", "Rappels par date ou par kilomètres")],
]

struct StoreScreenshot: View {
    let size: CGSize
    let caption: (String, String)
    let screenshot: NSImage
    let isPad: Bool

    var body: some View {
        let top: CGFloat = isPad ? 560 : 600
        let frameHeight = size.height - top - 60
        let bezel: CGFloat = isPad ? 26 : 30
        let screenHeight = frameHeight - bezel * 2
        let screenWidth = screenHeight * screenshot.size.width / screenshot.size.height
        let radius: CGFloat = isPad ? 70 : screenWidth * 0.12

        ZStack(alignment: .top) {
            Background()
            VStack(spacing: isPad ? 30 : 28) {
                Text(caption.0)
                    .font(.system(size: isPad ? 128 : 116, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(caption.1)
                    .font(.system(size: isPad ? 66 : 60, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(width: size.width - (isPad ? 240 : 140), height: top - 130)
            .padding(.top, isPad ? 90 : 110)

            Image(nsImage: screenshot)
                .resizable()
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .padding(bezel)
                .background(Color(red: 0.11, green: 0.12, blue: 0.17),
                            in: RoundedRectangle(cornerRadius: radius + bezel, style: .continuous))
                .shadow(color: Palette.ink.opacity(0.22), radius: 60, y: 30)
                .padding(.top, top)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

@MainActor
func renderScreenshots(in out: URL) throws {
    let devices: [(folder: String, size: CGSize)] = [("iphone", CGSize(width: 1320, height: 2868)),
                                                     ("ipad", CGSize(width: 2064, height: 2752))]
    for device in devices {
        for language in languages {
            let source = out.appendingPathComponent("Source/screens/\(device.folder)/\(language.lang)", isDirectory: true)
            guard let files = try? FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else {
                print("no screenshots in \(source.path), skipped")
                continue
            }
            let folder = out.appendingPathComponent("\(language.folder)/\(device.folder)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files.filter({ $0.pathExtension == "png" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let screen = file.deletingPathExtension().lastPathComponent.split(separator: "_", maxSplits: 1).last.map(String.init) ?? ""
                guard let caption = captions[screen]?[language.lang], let image = NSImage(contentsOf: file) else {
                    print("no caption for \(file.lastPathComponent), skipped")
                    continue
                }
                try render(StoreScreenshot(size: device.size, caption: caption, screenshot: image, isPad: device.folder == "ipad"),
                           size: device.size, to: folder.appendingPathComponent(file.lastPathComponent))
            }
        }
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
    try renderScreenshots(in: out)
}
