import SwiftUI
import UIKit

/// Apple TV design tokens. Every colour adapts to the TV's Light/Dark appearance
/// (Settings › General › Appearance), so nothing is white-on-white or invisible in light mode.
enum TVTheme {
    enum Radius {
        /// Buttons (bordered, prominent, plain-with-background): one rounded-rectangle shape everywhere.
        static let button: CGFloat = 18
        /// Small tiles and chips inside a panel.
        static let tile: CGFloat = 16
        /// Panels and banners.
        static let panel: CGFloat = 36
        /// Pop-ups drawn by the app (number pad, game over).
        static let sheet: CGFloat = 44
    }

    enum Colors {
        /// Subtle fill for inactive tiles, empty habit squares, etc.
        static let surface = adaptive(light: UIColor.black.withAlphaComponent(0.06),
                                      dark: UIColor.white.withAlphaComponent(0.08))
        /// Outline for tiles that sit on `surface`.
        static let outline = adaptive(light: UIColor.black.withAlphaComponent(0.18),
                                      dark: UIColor.white.withAlphaComponent(0.4))
        /// Scoreboard backdrop (top and bottom of the gradient).
        static let scoreboardTop = adaptive(light: UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1),
                                            dark: UIColor(red: 0.11, green: 0.18, blue: 0.31, alpha: 1))
        static let scoreboardBottom = adaptive(light: UIColor(red: 0.80, green: 0.85, blue: 0.93, alpha: 1),
                                               dark: UIColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1))
        /// Opaque background for the app's own pop-ups.
        static let popup = adaptive(light: UIColor(white: 0.97, alpha: 1),
                                    dark: UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1))
        /// Dims the screen behind an overlay.
        static let scrim = adaptive(light: UIColor.black.withAlphaComponent(0.3),
                                    dark: UIColor.black.withAlphaComponent(0.55))

        private static func adaptive(light: UIColor, dark: UIColor) -> Color {
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        }
    }
}

extension View {
    /// Applies the app's button shape to every bordered button below this view.
    /// Set on each root (tabs, the full-screen scoreboard, sheets), since presentations
    /// don't always inherit it.
    func tvThemed() -> some View {
        buttonBorderShape(.roundedRectangle(radius: TVTheme.Radius.button))
    }
}
