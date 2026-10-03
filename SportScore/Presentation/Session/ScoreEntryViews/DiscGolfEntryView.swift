import SwiftUI

struct DiscGolfEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var strokes: Int = 3

    private let relativePar: [(label: String, delta: Int, color: Color)] = [
        ("Ace / HIO", -99, .yellow),
        ("Eagle", -2, .orange),
        ("Birdie", -1, .blue),
        ("Par", 0, .green),
        ("Bogey", +1, .gray),
        ("Double", +2, .red),
        ("Triple+", +3, .red),
    ]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Strokes this hole")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button { strokes = max(1, strokes - 1) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                Text("\(strokes)")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.bouncy, value: strokes)
                    .frame(minWidth: 60)

                Button { strokes = min(20, strokes + 1) } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
            }

            Button("Record \(strokes) stroke\(strokes == 1 ? "" : "s")") {
                onSubmit(ScoreEntry(value: strokes))
                strokes = 3
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}
