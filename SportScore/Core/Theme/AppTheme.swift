import SwiftUI

enum AppTheme {
    // MARK: - Colours
    enum Colors {
        static let accent = Color.blue
        static let destructive = Color.red
        static let success = Color.green
        static let scoreCard = Color(.secondarySystemBackground)
    }

    // MARK: - Typography
    enum Typography {
        static let scoreLarge = Font.system(size: 56, weight: .bold, design: .rounded)
        static let scoreMedium = Font.system(size: 36, weight: .semibold, design: .rounded)
        static let scoreSmall = Font.system(size: 24, weight: .medium, design: .rounded)
        static let label = Font.system(size: 14, weight: .medium)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner radius
    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let small: CGFloat = 8
    }
}

// MARK: - Liquid Glass helper (iOS 26)
extension View {
    func sportScoreCard() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}
