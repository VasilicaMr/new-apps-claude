import SwiftUI

struct BackgammonEntryView: View {
    let activePlayer: Player
    let onSubmit: (ScoreEntry) -> Void

    @State private var cubeValue: Int = 1
    private let cubeValues = [1, 2, 4, 8, 16, 32, 64]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Doubling cube")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Doubling cube", selection: $cubeValue) {
                    ForEach(cubeValues, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("\(activePlayer.name) won with…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppTheme.Spacing.sm) {
                    resultButton(label: "Single", value: 1)
                    resultButton(label: "Gammon", value: 2)
                    resultButton(label: "Backgammon", value: 3)
                }
            }
        }
    }

    private func resultButton(label: String, value: Int) -> some View {
        Button {
            var meta = ["cubeValue": "\(cubeValue)"]
            if value == 2 { meta["gammon"] = "true" }
            if value == 3 { meta["backgammon"] = "true" }
            onSubmit(ScoreEntry(value: value, metadata: meta))
            cubeValue = 1
        } label: {
            VStack(spacing: 2) {
                Text(label).font(.caption.bold())
                Text("+\(value * cubeValue)").font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
