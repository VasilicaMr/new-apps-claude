import SwiftUI

struct DartsEntryView: View {
    let sport: SportType
    let onSubmit: (ScoreEntry) -> Void

    @State private var multiplier: Int = 1
    @State private var segment: Int = 20

    private let segments = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            multiplierRow
            segmentGrid
            specialButtons
        }
    }

    private var multiplierRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            multiplierButton(value: 1, label: "Single")
            multiplierButton(value: 2, label: "Double")
            multiplierButton(value: 3, label: "Triple")
        }
    }

    @ViewBuilder
    private func multiplierButton(value: Int, label: String) -> some View {
        if multiplier == value {
            Button(label) { multiplier = value }
                .buttonStyle(.borderedProminent)
                .font(.caption.bold())
        } else {
            Button(label) { multiplier = value }
                .buttonStyle(.bordered)
                .font(.caption.bold())
        }
    }

    private var segmentGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
            ForEach(segments, id: \.self) { seg in
                Button("\(seg)") {
                    submit(value: multiplier * seg, meta: ["segment": "\(seg)", "multiplier": "\(multiplier)"])
                }
                .buttonStyle(.bordered)
                .font(.caption.monospacedDigit())
            }
        }
    }

    private var specialButtons: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Button("Bull (25)") {
                submit(value: 25, meta: ["segment": "bull", "multiplier": "1"])
            }
            .buttonStyle(.bordered)

            Button("D.Bull (50)") {
                submit(value: 50, meta: ["segment": "bull", "multiplier": "2"])
            }
            .buttonStyle(.bordered)

            Button("Miss (0)") {
                submit(value: 0, meta: ["segment": "0", "multiplier": "1"])
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .font(.caption.bold())
    }

    private func submit(value: Int, meta: [String: String]) {
        onSubmit(ScoreEntry(value: value, metadata: meta))
        multiplier = 1
    }
}
