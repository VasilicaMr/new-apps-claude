import SwiftUI

enum Theme {
    static let accent = Color("AccentColor")
    static let positive = Color.green
    static let negative = Color.red
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 16

    static func color(for urgency: Urgency) -> Color {
        switch urgency {
        case .ok: .secondary
        case .soon: .orange
        case .overdue: .red
        }
    }

    static func symbol(for urgency: Urgency) -> String {
        switch urgency {
        case .ok: "checkmark.circle"
        case .soon: "exclamationmark.triangle.fill"
        case .overdue: "exclamationmark.octagon.fill"
        }
    }

    static func color(forNet value: Double) -> Color { value < 0 ? negative : .primary }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

extension EnvironmentValues {
    /// Money formatter for the currency chosen in Settings.
    @Entry var money = MoneyFormatter(currencyCode: MoneyFormatter.defaultCurrencyCode)
}
