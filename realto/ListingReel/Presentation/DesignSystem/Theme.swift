import SwiftUI

/// Lightweight design tokens for the app chrome (distinct from per-template
/// render tokens, which live in the Domain).
///
/// Look (shared with Drivo and Monteo): warm cream → sky canvas, deep navy
/// ink, white cards with a hairline edge, and simple two-stop gradients for
/// the things you tap. Dark mode swaps to a night-blue canvas with the same
/// accents. Camera, preview and trim screens stay dark regardless (they
/// frame video).
enum Theme {
    enum Palette {
        // Canvas
        static let background = Color.adaptive(
            light: Color(red: 0.99, green: 0.97, blue: 0.93),
            dark: Color(red: 0.10, green: 0.14, blue: 0.26))
        static let backgroundEnd = Color.adaptive(
            light: Color(red: 0.90, green: 0.95, blue: 0.99),
            dark: Color(red: 0.16, green: 0.12, blue: 0.28))

        // Surfaces
        static let surface = Color.adaptive(
            light: Color.white.opacity(0.88),
            dark: Color(red: 0.17, green: 0.19, blue: 0.30).opacity(0.92))
        static let surfaceElevated = Color.adaptive(
            light: Color(red: 0.90, green: 0.95, blue: 0.99),
            dark: Color.white.opacity(0.08))
        static let stroke = Color.adaptive(
            light: Color(red: 0.14, green: 0.20, blue: 0.32).opacity(0.07),
            dark: Color.white.opacity(0.08))
        static let shadow = Color.adaptive(
            light: Color.black.opacity(0.06),
            dark: Color.black.opacity(0.30))
        /// Hairline on top of gradient cards and filled buttons.
        static let gradientStroke = Color.white.opacity(0.30)

        // Accents
        static let accent = Color(red: 0.35, green: 0.48, blue: 0.95)      // Monteo blue
        static let accentAlt = Color(red: 0.98, green: 0.62, blue: 0.35)   // warm peach
        static let gold = Color(red: 0.96, green: 0.80, blue: 0.28)        // premium
        static let violet = Color(red: 0.55, green: 0.40, blue: 0.95)
        static let teal = Color(red: 0.22, green: 0.58, blue: 0.72)
        /// Text and icons drawn on top of `accent`.
        static let onAccent = Color.white

        // Text
        static let textPrimary = Color.adaptive(
            light: Color(red: 0.14, green: 0.20, blue: 0.32),
            dark: Color(red: 0.94, green: 0.95, blue: 0.98))
        static let textSecondary = Color.adaptive(
            light: Color(red: 0.14, green: 0.20, blue: 0.32).opacity(0.62),
            dark: Color(red: 0.94, green: 0.95, blue: 0.98).opacity(0.62))

        // Feedback
        static let danger = Color(red: 0.95, green: 0.45, blue: 0.48)
        static let success = Color(red: 0.22, green: 0.72, blue: 0.48)
        static let warning = Color(red: 0.98, green: 0.62, blue: 0.22)
    }

    /// One gradient per job, so tiles are easy to tell apart.
    enum Gradients {
        /// Primary buttons and progress: blue → violet.
        static let primary = gradient((0.38, 0.55, 0.98), (0.55, 0.40, 0.95))
        /// Hero cards and feature badges: blue → peach.
        static let hero = gradient((0.42, 0.62, 0.92), (0.98, 0.78, 0.55))
        /// Premium highlights: sunny gold → orange.
        static let premium = gradient((1.00, 0.78, 0.36), (1.00, 0.56, 0.32))
        /// Media and clips: mint → teal.
        static let media = gradient((0.40, 0.82, 0.62), (0.22, 0.58, 0.72))
        /// Voice and AI: cyan → blue.
        static let voice = gradient((0.25, 0.72, 0.82), (0.35, 0.48, 0.95))
        /// Open house and calendar: peach → coral.
        static let calendar = gradient((1.00, 0.72, 0.38), (0.95, 0.48, 0.42))
        /// Destructive actions.
        static let danger = gradient((0.96, 0.42, 0.45), (0.86, 0.26, 0.36))

        private static func gradient(_ from: (Double, Double, Double), _ to: (Double, Double, Double)) -> LinearGradient {
            LinearGradient(colors: [Color(red: from.0, green: from.1, blue: from.2), Color(red: to.0, green: to.1, blue: to.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
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

    /// Rounded, heavy navy titles in navigation bars and rounded segmented
    /// controls, like Drivo's. Call once at launch; no-op on macOS.
    static func applyAppearance() {
        #if os(iOS)
        let ink = UIColor(Palette.textPrimary)
        func rounded(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) } ?? base
        }
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [.font: rounded(.largeTitle, .heavy), .foregroundColor: ink]
        navigation.titleTextAttributes = [.font: rounded(.headline, .bold), .foregroundColor: ink]
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = UIColor(Palette.accent)
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: rounded(.subheadline, .bold)], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: ink, .font: rounded(.subheadline, .semibold)], for: .normal)
        #endif
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

/// Cream → sky canvas; purely decorative.
struct ThemeBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.Palette.background, Theme.Palette.backgroundEnd],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

extension View {
    /// Standard screen background used across the app. Expands to the full
    /// available space first so the background fills the whole window on
    /// macOS instead of just hugging its (often narrower) content. Hides
    /// List/Form's grey so the canvas shows through.
    func screenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThemeBackground())
    }

    /// Soft white card: rounded, hairline stroke, gentle shadow.
    func cardSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.Palette.stroke, lineWidth: 1))
            .shadow(color: Theme.Palette.shadow, radius: 12, y: 5)
    }

    /// A saturated gradient card with white content.
    func gradientCard(_ gradient: LinearGradient, radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .foregroundStyle(Theme.Palette.onAccent)
            .background(gradient, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.Palette.gradientStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }
}

/// Rounded gradient tile holding an SF Symbol — used for feature and step icons.
struct GradientIconBadge: View {
    let systemImage: String
    var gradient: LinearGradient = Theme.Gradients.hero
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: size, height: size)
            .background(gradient, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).stroke(Theme.Palette.gradientStroke, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// An SF Symbol on a soft rounded square of its own tint.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = Theme.Palette.accent
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A small tinted capsule label, e.g. "3 clips".
struct Chip: View {
    let text: LocalizedStringKey
    var systemImage: String? = nil
    var tint: Color = Theme.Palette.accent

    var body: some View {
        Group {
            if let systemImage { Label(text, systemImage: systemImage) } else { Text(text) }
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Card press: a gentle shrink.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
