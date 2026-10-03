import SwiftUI

/// Lightweight design tokens for the app chrome (distinct from per-template
/// render tokens, which live in the Domain).
enum Theme {
    enum Palette {
        static let background = Color(red: 0.04, green: 0.05, blue: 0.09)
        static let surface = Color(red: 0.10, green: 0.12, blue: 0.17)
        static let surfaceElevated = Color(red: 0.14, green: 0.16, blue: 0.22)
        static let accent = Color(red: 0.79, green: 0.64, blue: 0.15)      // gold
        static let accentAlt = Color(red: 0.30, green: 0.56, blue: 1.0)    // blue
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let danger = Color(red: 0.95, green: 0.30, blue: 0.32)
        static let success = Color(red: 0.30, green: 0.80, blue: 0.55)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
    }
}

extension View {
    /// Standard screen background used across the app. Expands to the full
    /// available space first so the background fills the whole window on
    /// macOS instead of just hugging its (often narrower) content.
    func screenBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.background.ignoresSafeArea())
    }
}
