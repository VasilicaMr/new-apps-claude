import SwiftUI

/// CodeRelay's terminal look: near-black canvas, phosphor-mint accent, monospaced type.
enum Theme {
    static let background = Color(hex: 0x0B0D10)
    static let surface = Color(hex: 0x14181D)
    static let surfaceRaised = Color(hex: 0x1C2128)
    static let border = Color(hex: 0x2A313A)
    static let text = Color(hex: 0xE6EDF3)
    static let dim = Color(hex: 0x7D8590)
    static let accent = Color(hex: 0x5CF2B5)
    static let tool = Color(hex: 0x79C0FF)
    static let warning = Color(hex: 0xF2CC60)
    static let danger = Color(hex: 0xFF7B72)
    static let ai = Color(hex: 0xD2A8FF)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum PreferenceKeys {
    static let fontSize = "terminalFontSize"
    static let autoSuggest = "aiAutoSuggest"
    static let autoTitle = "aiAutoTitle"
    static let haptics = "haptics"
    static let hasOnboarded = "hasOnboarded"
}

/// Card container used across screens.
struct TerminalCard<Content: View>: View {
    var tint: Color = Theme.border
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint, lineWidth: 1))
    }
}

struct AccentButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(15, weight: .semibold))
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = Theme.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(14, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.surfaceRaised.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border))
    }
}
