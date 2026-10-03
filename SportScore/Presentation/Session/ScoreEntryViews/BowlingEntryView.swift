import SwiftUI

struct BowlingEntryView: View {
    /// Pins still standing for this ball; the input can never exceed it.
    var maxPins: Int = 10
    let onSubmit: (ScoreEntry) -> Void

    @State private var pinsDown: Int = 0

    private var allDownLabel: String {
        maxPins == 10 ? "Strike" : "Spare (\(maxPins))"
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("\(pinsDown)")
                .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.bouncy, value: pinsDown)
                .frame(height: 64)
                .accessibilityLabel("\(pinsDown) pins")

            HStack(spacing: AppTheme.Spacing.sm) {
                Button { pinsDown = max(0, pinsDown - 1) } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(pinsDown == 0)

                if maxPins > 0 {
                    Slider(value: Binding(
                        get: { Double(pinsDown) },
                        set: { pinsDown = Int($0.rounded()) }
                    ), in: 0...Double(maxPins), step: 1)
                }

                Button { pinsDown = min(maxPins, pinsDown + 1) } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(pinsDown >= maxPins)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Gutter (0)") { record(0) }
                    .buttonStyle(.bordered)
                Button(allDownLabel) { record(maxPins) }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(maxPins == 0)
            }
            .font(.callout.bold())

            Button("Record \(pinsDown) pin\(pinsDown == 1 ? "" : "s")") {
                record(pinsDown)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: maxPins) { _, new in pinsDown = min(pinsDown, new) }
    }

    private func record(_ pins: Int) {
        onSubmit(ScoreEntry(value: min(pins, maxPins)))
        pinsDown = 0
    }
}
