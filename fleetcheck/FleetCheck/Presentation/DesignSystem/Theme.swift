import SwiftUI
import UIKit

/// DriveCap's look, in the same family as Monteo: warm cream canvas, deep navy ink,
/// white cards with a hairline edge, and simple two-stop gradients for the things you tap.
enum Theme {

    // MARK: - Accents

    static let accent = Color("AccentColor")
    /// Monteo blue.
    static let blue = Color(red: 0.35, green: 0.48, blue: 0.95)
    static let positive = Color(red: 0.22, green: 0.72, blue: 0.48)
    static let negative = Color(red: 0.95, green: 0.45, blue: 0.48)
    static let warning = Color(red: 0.98, green: 0.62, blue: 0.22)
    static let gold = Color(red: 0.96, green: 0.80, blue: 0.28)

    // MARK: - Surfaces

    /// Deep friendly navy in light mode, near-white in dark.
    static let ink = Color(light: Color(red: 0.14, green: 0.20, blue: 0.32), dark: Color(red: 0.94, green: 0.95, blue: 0.98))
    static let inkSecondary = ink.opacity(0.62)
    static let cardBackground = Color(light: .white.opacity(0.88), dark: Color(red: 0.17, green: 0.19, blue: 0.30).opacity(0.92))
    static let cardStroke = Color(light: Color(red: 0.14, green: 0.20, blue: 0.32).opacity(0.07), dark: .white.opacity(0.08))
    static let cardShadow = Color(light: .black.opacity(0.06), dark: .black.opacity(0.30))
    /// Soft fill behind small icons and chips.
    static let wash = Color(light: Color(red: 0.90, green: 0.95, blue: 0.99), dark: .white.opacity(0.08))
    static let cornerRadius: CGFloat = 22

    static let canvasTop = Color(light: Color(red: 0.99, green: 0.97, blue: 0.93), dark: Color(red: 0.10, green: 0.14, blue: 0.26))
    static let canvasBottom = Color(light: Color(red: 0.90, green: 0.95, blue: 0.99), dark: Color(red: 0.16, green: 0.12, blue: 0.28))

    static var canvas: LinearGradient {
        LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Card gradients (one per job, easy to tell apart)

    /// Shifts: blue → violet.
    static let shiftGradient = gradient((0.38, 0.55, 0.98), (0.55, 0.40, 0.95))
    /// Earnings: sunny gold → orange.
    static let earningsGradient = gradient((1.00, 0.78, 0.36), (1.00, 0.56, 0.32))
    /// Receipts and costs: mint → teal.
    static let receiptGradient = gradient((0.40, 0.82, 0.62), (0.22, 0.58, 0.72))
    /// Voice and assistant: cyan → blue.
    static let voiceGradient = gradient((0.25, 0.72, 0.82), (0.35, 0.48, 0.95))
    /// Week and calendar: peach → coral.
    static let weekGradient = gradient((1.00, 0.72, 0.38), (0.95, 0.48, 0.42))
    /// Car and settings: dusk violet.
    static let carGradient = gradient((0.52, 0.48, 0.68), (0.38, 0.36, 0.52))
    static let profitGradient = gradient((0.22, 0.72, 0.48), (0.18, 0.55, 0.38))
    static let lossGradient = gradient((0.95, 0.50, 0.48), (0.82, 0.32, 0.40))
    static let stopGradient = gradient((0.96, 0.42, 0.45), (0.86, 0.26, 0.36))

    static let gradientStroke = Color.white.opacity(0.30)

    private static func gradient(_ from: (Double, Double, Double), _ to: (Double, Double, Double)) -> LinearGradient {
        LinearGradient(colors: [Color(red: from.0, green: from.1, blue: from.2), Color(red: to.0, green: to.1, blue: to.2)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Status

    static func color(for urgency: Urgency) -> Color {
        switch urgency {
        case .ok: inkSecondary
        case .soon: warning
        case .overdue: negative
        }
    }

    static func symbol(for urgency: Urgency) -> String {
        switch urgency {
        case .ok: "checkmark.circle"
        case .soon: "exclamationmark.triangle.fill"
        case .overdue: "exclamationmark.octagon.fill"
        }
    }

    static func color(forNet value: Double) -> Color { value < 0 ? negative : ink }

    // MARK: - UIKit chrome

    /// Rounded, heavy navy titles in navigation bars, like Monteo's headings.
    static func applyAppearance() {
        let ink = UIColor(Theme.ink)
        func rounded(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) } ?? base
        }
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [.font: rounded(.largeTitle, .heavy), .foregroundColor: ink]
        navigation.titleTextAttributes = [.font: rounded(.headline, .bold), .foregroundColor: ink]
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Theme.blue)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white, .font: rounded(.subheadline, .bold)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: ink, .font: rounded(.subheadline, .semibold)], for: .normal)
    }
}

extension Color {
    /// A color that follows light and dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

// MARK: - Cards and canvas

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.cardStroke, lineWidth: 1))
            .shadow(color: Theme.cardShadow, radius: 12, y: 5)
    }
}

/// A saturated gradient card with white content, like Monteo's home tiles.
struct GradientCardModifier: ViewModifier {
    let gradient: LinearGradient
    var cornerRadius: CGFloat = Theme.cornerRadius
    var shadow: Color = .black.opacity(0.12)

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .background(gradient, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Theme.gradientStroke, lineWidth: 1))
            .shadow(color: shadow, radius: 10, y: 5)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }

    func gradientCard(_ gradient: LinearGradient, cornerRadius: CGFloat = Theme.cornerRadius, shadow: Color = .black.opacity(0.12)) -> some View {
        modifier(GradientCardModifier(gradient: gradient, cornerRadius: cornerRadius, shadow: shadow))
    }

    /// The cream-to-sky canvas behind a screen; hides List/Form's grey so it shows through.
    func fleetBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
    }
}

extension EnvironmentValues {
    /// Money formatter for the currency chosen in Settings.
    @Entry var money = MoneyFormatter(currencyCode: MoneyFormatter.defaultCurrencyCode)
}
