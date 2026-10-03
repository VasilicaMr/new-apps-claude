import SwiftUI

struct GoEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var territory: Int = 0

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Stones captured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach([1, 2, 3, 5], id: \.self) { n in
                        Button("+\(n)") {
                            onSubmit(ScoreEntry(value: n, label: "capture"))
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("End of game — territory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $territory, in: 0...361) {
                    Text("\(territory) points")
                        .font(.title3.bold().monospacedDigit())
                }
                Button("Submit final territory") {
                    onSubmit(ScoreEntry(value: territory, label: "territory"))
                    territory = 0
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
