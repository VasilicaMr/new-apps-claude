import SwiftUI

struct ArcheryEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    private let rings: [(label: String, value: Int, color: Color)] = [
        ("X", 10, .yellow),
        ("10", 10, .yellow),
        ("9", 9, .yellow),
        ("8", 8, .red),
        ("7", 7, .red),
        ("6", 6, .blue),
        ("5", 5, .blue),
        ("4", 4, .black),
        ("3", 3, .black),
        ("2", 2, .white),
        ("1", 1, .white),
        ("M", 0, .gray),
    ]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Tap arrow score")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(rings, id: \.label) { ring in
                    Button(ring.label) {
                        let meta: [String: String] = ring.label == "X" ? ["isX": "true"] : [:]
                        onSubmit(ScoreEntry(value: ring.value, metadata: meta.isEmpty ? nil : meta))
                    }
                    .font(.callout.bold())
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(ring.color.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ring.color.opacity(0.6)))
                    .foregroundStyle(ring.color == .white ? .primary : ring.color)
                }
            }
        }
    }
}
