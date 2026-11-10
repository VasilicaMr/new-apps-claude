import SwiftUI

/// Primary call-to-action button.
///
/// `title` is a `LocalizedStringKey` so every call site's string literal is
/// automatically picked up by the `Localizable.xcstrings` catalog. Accessibility
/// identifiers must NOT be derived from localizable text (UI tests need a stable
/// identifier regardless of the device's language), so pass `accessibilityID`
/// explicitly wherever automation targets this button.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if isLoading {
                    ProgressView().tint(Theme.Palette.onAccent)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if isEnabled {
                    Capsule().fill(Theme.Gradients.primary)
                } else {
                    Capsule().fill(Theme.Palette.surfaceElevated)
                }
            }
            .overlay(Capsule().stroke(Theme.Palette.gradientStroke.opacity(isEnabled ? 1 : 0), lineWidth: 1))
            .foregroundStyle(isEnabled ? Theme.Palette.onAccent : Theme.Palette.textSecondary)
            .shadow(color: Theme.Palette.accent.opacity(isEnabled ? 0.30 : 0), radius: 6, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}

/// Secondary/outline button. See `PrimaryButton` for the localization/accessibility note.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Theme.Palette.accent)
            .background(Theme.Palette.accent.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}

/// Standard wizard-step chrome: a step indicator, a scrollable content area, and
/// a pinned bottom action bar. Keeps all step screens visually consistent.
struct StepScaffold<Content: View, Footer: View>: View {
    let route: AppRoute
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            StepProgressBar(current: route.stepIndex, total: AppRoute.totalSteps)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    content()
                }
                .padding(Theme.Spacing.l)
            }

            VStack {
                footer()
            }
            .padding(Theme.Spacing.l)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(route.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .screenBackground()
    }
}

struct StepProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(1...total, id: \.self) { i in
                Group {
                    if i <= current {
                        Capsule().fill(Theme.Gradients.primary)
                    } else {
                        Capsule().fill(Theme.Palette.surfaceElevated)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

/// A labelled section header used inside steps.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(.system(.title3, design: .rounded, weight: .heavy)).foregroundStyle(Theme.Palette.textPrimary)
            if let subtitle {
                Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }
}

/// Cross-platform hint for the on-screen keyboard; ignored on macOS, which has
/// no virtual keyboard — the Mac's hardware keyboard handles all field types.
enum FieldKeyboard {
    case `default`, numberPad, decimalPad, phonePad, emailAddress

    #if os(iOS)
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default:      return .default
        case .numberPad:    return .numberPad
        case .decimalPad:   return .decimalPad
        case .phonePad:     return .phonePad
        case .emailAddress: return .emailAddress
        }
    }
    #endif
}

/// Card-styled text field used across the branding/property steps. `label` and
/// `placeholder` are `LocalizedStringKey`s (see `PrimaryButton` for why
/// `accessibilityID` must be passed explicitly rather than derived from them).
struct FieldRow: View {
    let label: LocalizedStringKey
    var placeholder: LocalizedStringKey = ""
    @Binding var text: String
    var keyboard: FieldKeyboard = .default
    var accessibilityID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.textSecondary)
            TextField(placeholder, text: $text)
                #if os(iOS)
                .keyboardType(keyboard.uiKeyboardType)
                #endif
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.m)
                .foregroundStyle(Theme.Palette.textPrimary)
                .cardSurface(radius: Theme.Radius.control)
                .accessibilityIdentifier(accessibilityID ?? "")
        }
    }
}
