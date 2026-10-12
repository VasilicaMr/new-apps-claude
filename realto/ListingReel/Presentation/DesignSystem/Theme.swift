import SwiftUI

/// Lightweight design tokens for the app chrome (distinct from per-template
/// render tokens, which live in the Domain).
///
/// Look: warm cream → sky canvas, deep navy ink, a calm blue primary and
/// blue → peach gradients for hero moments, on soft white cards. Dark mode
/// swaps to a night-blue canvas with the same accents. Camera, preview and
/// trim screens stay dark regardless (they frame video).
enum Theme {
    enum Palette {
        // Canvas
        static let background = Color.adaptive(
            light: Color(red: 0.99, green: 0.97, blue: 0.93),
            dark: Color(red: 0.08, green: 0.10, blue: 0.19))
        static let backgroundEnd = Color.adaptive(
            light: Color(red: 0.90, green: 0.95, blue: 0.99),
            dark: Color(red: 0.14, green: 0.11, blue: 0.25))

        // Surfaces
        static let surface = Color.adaptive(
            light: Color.white.opacity(0.94),
            dark: Color(red: 0.15, green: 0.16, blue: 0.27))
        static let surfaceElevated = Color.adaptive(
            light: Color(red: 0.92, green: 0.93, blue: 0.97),
            dark: Color(red: 0.21, green: 0.22, blue: 0.34))
        static let stroke = Color.adaptive(
            light: Color(red: 0.14, green: 0.20, blue: 0.32).opacity(0.08),
            dark: Color.white.opacity(0.10))

        // Accents
        static let accent = Color(red: 0.35, green: 0.48, blue: 0.95)      // primary blue
        static let accentAlt = Color(red: 0.98, green: 0.62, blue: 0.35)   // warm peach
        static let gold = Color(red: 0.96, green: 0.76, blue: 0.26)        // premium
        /// Text and icons drawn on top of `accent`.
        static let onAccent = Color.white

        // Text
        static let textPrimary = Color.adaptive(
            light: Color(red: 0.14, green: 0.20, blue: 0.32),
            dark: Color.white)
        static let textSecondary = Color.adaptive(
            light: Color(red: 0.14, green: 0.20, blue: 0.32).opacity(0.62),
            dark: Color.white.opacity(0.68))

        // Feedback
        static let danger = Color(red: 0.95, green: 0.42, blue: 0.45)
        static let success = Color(red: 0.22, green: 0.72, blue: 0.48)
    }

    enum Gradients {
        /// Primary buttons and progress: blue → violet.
        static let primary = LinearGradient(
            colors: [Color(red: 0.38, green: 0.55, blue: 0.98), Color(red: 0.50, green: 0.40, blue: 0.95)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        /// Hero cards and feature badges: blue → peach.
        static let hero = LinearGradient(
            colors: [Color(red: 0.42, green: 0.62, blue: 0.92), Color(red: 0.98, green: 0.78, blue: 0.55)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        /// Premium highlights: sun → coral.
        static let premium = LinearGradient(
            colors: [Color(red: 1.00, green: 0.82, blue: 0.38), Color(red: 0.98, green: 0.55, blue: 0.40)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 16
    }
}

extension Color {
    /// Light/dark adaptive color without an asset-catalog entry.
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}

/// Cream → sky canvas with two soft colour glows; purely decorative.
struct ThemeBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.Palette.background, Theme.Palette.backgroundEnd],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                Circle()
                    .fill(Theme.Palette.accentAlt.opacity(scheme == .dark ? 0.10 : 0.20))
                    .frame(width: w * 0.6).blur(radius: 50)
                    .position(x: w * 0.05, y: h * 0.06)
                Circle()
                    .fill(Theme.Palette.accent.opacity(scheme == .dark ? 0.16 : 0.14))
                    .frame(width: w * 0.7).blur(radius: 60)
                    .position(x: w * 0.95, y: h * 0.95)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    /// Standard screen background used across the app. Expands to the full
    /// available space first so the background fills the whole window on
    /// macOS instead of just hugging its (often narrower) content.
    func screenBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThemeBackground())
    }

    /// Soft white card: rounded, hairline stroke, gentle shadow.
    func cardSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.Palette.stroke))
            .shadow(color: Color.black.opacity(0.07), radius: 12, y: 5)
    }
}

/// Rounded gradient tile holding an SF Symbol — used for feature and step icons.
struct GradientIconBadge: View {
    let systemImage: String
    var gradient: LinearGradient = Theme.Gradients.hero
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: size, height: size)
            .background(gradient, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
