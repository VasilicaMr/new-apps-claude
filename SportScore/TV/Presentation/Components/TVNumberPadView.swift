import SwiftUI

/// On-screen number pad: much faster with the Siri Remote than the system keyboard.
/// Used as the "Custom…" fallback wherever iOS lets the user type a score.
struct TVNumberPadView: View {
    let title: String
    var maxValue: Int? = nil
    var confirmTitle: (Int) -> String = { "Add \($0)" }
    let onCommit: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @Namespace private var padNamespace

    private var value: Int { Int(digits) ?? 0 }
    private var isValid: Bool { maxValue.map { value <= $0 } ?? true }
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "⌫"]

    var body: some View {
        VStack(spacing: 36) {
            Text(title)
                .font(.title2.bold())

            Text(digits.isEmpty ? "0" : digits)
                .font(.system(size: 130, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isValid ? .primary : Color.red)
                .contentTransition(.numericText())

            if let maxValue, !isValid {
                Text("Maximum is \(maxValue)")
                    .foregroundStyle(.red)
            }

            Grid(horizontalSpacing: 24, verticalSpacing: 24) {
                ForEach(0..<4) { row in
                    GridRow {
                        ForEach(0..<3) { column in
                            let key = keys[row * 3 + column]
                            Button {
                                press(key)
                            } label: {
                                Text(key)
                                    .font(.title.weight(.semibold))
                                    .frame(width: 130, height: 76)
                            }
                            // Start on "1" rather than on the key nearest the button that opened the pad.
                            .prefersDefaultFocus(key == "1", in: padNamespace)
                        }
                    }
                }
            }

            Button {
                onCommit(value)
                dismiss()
            } label: {
                Label(confirmTitle(value), systemImage: "checkmark.circle.fill")
                    .frame(minWidth: 360)
            }
            .buttonStyle(.borderedProminent)
            .disabled(digits.isEmpty || !isValid)
        }
        .padding(60)
        // Opaque, so the scoreboard's buttons don't show through the keys.
        .background(TVTheme.Colors.popup, in: RoundedRectangle(cornerRadius: TVTheme.Radius.sheet))
        .focusScope(padNamespace)
        .tvThemed()
    }

    private func press(_ key: String) {
        withAnimation(.snappy) {
            switch key {
            case "C": digits = ""
            case "⌫": digits = String(digits.dropLast())
            default:
                guard digits.count < 8, !(digits.isEmpty && key == "0") else { return }
                digits += key
            }
        }
    }
}
