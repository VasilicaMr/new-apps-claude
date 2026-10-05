import SwiftUI

/// On-screen number pad — much faster with the Siri Remote than the system keyboard.
struct PointsPadView: View {
    let participant: Participant
    /// In count-down games (darts) the main action subtracts.
    let countsDown: Bool
    let onCommit: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""

    private var value: Int { Int(digits) ?? 0 }
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "⌫"]

    var body: some View {
        VStack(spacing: 36) {
            Text(participant.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(PlayerPalette.color(participant.colorIndex))

            Text(digits.isEmpty ? "0" : digits)
                .font(.system(size: 130, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

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
                        }
                    }
                }
            }

            HStack(spacing: 40) {
                Button {
                    commit(countsDown ? -value : value)
                } label: {
                    Label(countsDown ? "Score −\(value)" : "Add +\(value)", systemImage: "checkmark.circle.fill")
                        .frame(minWidth: 320)
                }
                Button {
                    commit(countsDown ? value : -value)
                } label: {
                    Label(countsDown ? "Add Back +\(value)" : "Subtract −\(value)", systemImage: "minus.circle")
                        .frame(minWidth: 320)
                }
            }
            .disabled(value == 0)
        }
        .padding(60)
    }

    private func press(_ key: String) {
        withAnimation(.snappy) {
            switch key {
            case "C": digits = ""
            case "⌫": digits = String(digits.dropLast())
            default:
                guard digits.count < 6, !(digits.isEmpty && key == "0") else { return }
                digits += key
            }
        }
    }

    private func commit(_ delta: Int) {
        onCommit(delta)
        dismiss()
    }
}
