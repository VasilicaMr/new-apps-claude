import SwiftUI

struct KPITile: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    var tint: Color = Theme.ink
    var footnote: String?
    var iconTint: Color = Theme.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                IconBadge(symbol: symbol, tint: iconTint, size: 28)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let footnote {
                Text(footnote).font(.caption2.weight(.medium)).foregroundStyle(Theme.inkSecondary).lineLimit(1)
            }
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            if let subtitle { Text(subtitle).font(.caption.weight(.medium)).foregroundStyle(Theme.inkSecondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An SF Symbol on a soft rounded square of its own tint.
struct IconBadge: View {
    let symbol: String
    var tint: Color = Theme.blue
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A small tinted capsule label, e.g. "3 trips".
struct Chip: View {
    let text: LocalizedStringKey
    var symbol: String?
    var tint: Color = Theme.blue

    var body: some View {
        Group {
            if let symbol { Label(text, systemImage: symbol) } else { Text(text) }
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: .capsule)
    }
}

/// A big tappable gradient tile: icon, title and subtitle in white.
struct GradientTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let gradient: LinearGradient
    var height: CGFloat = 132
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.18), in: .rect(cornerRadius: 13, style: .continuous))
                Spacer(minLength: 6)
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .opacity(0.88)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .gradientCard(gradient)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(.isButton)
    }
}

/// Monteo's card press: a gentle shrink.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Monteo's pill button: a filled gradient capsule with white bold rounded text.
/// `filled: false` gives the quieter tinted version.
struct CapsuleButtonStyle: ButtonStyle {
    var tint: Color = Theme.blue
    var filled = true
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        CapsuleButton(configuration: configuration, tint: tint, filled: filled, compact: compact)
    }

    private struct CapsuleButton: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration
        let tint: Color
        let filled: Bool
        let compact: Bool

        var body: some View {
            let pressed = configuration.isPressed
            configuration.label
                .font(.system(size: compact ? 14 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(filled ? .white : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, compact ? 14 : 20)
                .frame(minHeight: compact ? 34 : 50)
                .background {
                    if filled {
                        Capsule().fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
                    } else {
                        Capsule().fill(tint.opacity(0.12))
                    }
                }
                .overlay(Capsule().stroke(.white.opacity(filled ? 0.30 : 0), lineWidth: 1))
                .shadow(color: filled ? tint.opacity(0.30) : .clear, radius: pressed ? 2 : 6, y: pressed ? 1 : 4)
                .scaleEffect(pressed ? 0.96 : 1)
                .opacity(isEnabled ? 1 : 0.5)
                .animation(.easeOut(duration: 0.12), value: pressed)
                .contentShape(Capsule())
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let status: ReminderStatus

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: reminder.kind.symbol,
                      tint: status.urgency == .ok ? Theme.blue : Theme.color(for: status.urgency))
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if status.urgency > .ok {
                Label(status.urgency == .overdue ? "Overdue" : "Soon", systemImage: Theme.symbol(for: status.urgency))
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Theme.color(for: status.urgency))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var parts: [String] = []
        if let date = reminder.dueDate, let days = status.daysLeft {
            let when = date.formatted(date: .abbreviated, time: .omitted)
            let text = switch days {
            case ..<0: String(localized: "Expired \(when)")
            case 0: String(localized: "Due today")
            case 1: String(localized: "Due tomorrow")
            default: String(localized: "\(when) · in \(days) days")
            }
            parts.append(text)
        }
        if let km = status.kmLeft {
            parts.append(km <= 0 ? String(localized: "Overdue by \(abs(km).kilometers)") : String(localized: "In \(km.kilometers)"))
        }
        return parts.isEmpty ? String(localized: "No due date set") : parts.joined(separator: " · ")
    }
}

/// A number field that edits an optional or plain Double, with the keyboard suited for money.
struct AmountField: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    var currencyCode: String?

    var body: some View {
        LabeledContent(title) {
            Group {
                if let currencyCode {
                    TextField(title, value: $value, format: .currency(code: currencyCode))
                } else {
                    TextField(title, value: $value, format: .number)
                }
            }
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
    }
}
