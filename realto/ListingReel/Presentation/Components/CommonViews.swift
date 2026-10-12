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
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .background {
                let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                if isEnabled {
                    shape.fill(Theme.Gradients.primary)
                } else {
                    shape.fill(Theme.Palette.surfaceElevated)
                }
            }
            .foregroundStyle(isEnabled ? Theme.Palette.onAccent : Theme.Palette.textSecondary)
            .shadow(color: Theme.Palette.accent.opacity(isEnabled ? 0.30 : 0), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
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
                Text(title).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .foregroundStyle(Theme.Palette.textPrimary)
            .cardSurface(radius: Theme.Radius.control)
        }
        .buttonStyle(.plain)
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
            Text(title).font(.system(.title3, design: .rounded).bold()).foregroundStyle(Theme.Palette.textPrimary)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.Palette.textSecondary)
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
