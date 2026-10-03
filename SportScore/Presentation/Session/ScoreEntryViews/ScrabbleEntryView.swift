import SwiftUI

struct ScrabbleEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var wordScore: Int = 0
    @State private var isBingo: Bool = false
    @State private var isChallenged: Bool = false

    var total: Int { wordScore + (isBingo ? 50 : 0) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: 20) {
                Button { wordScore = max(0, wordScore - 1) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                VStack(spacing: 2) {
                    Text("\(total)")
                        .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.bouncy, value: total)
                    if isBingo {
                        Text("Bingo +50")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .frame(minWidth: 80)

                Button { wordScore += 1 } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Toggle("Bingo (+50)", isOn: $isBingo)
                    .toggleStyle(.button)
                    .font(.caption.bold())

                Toggle("Challenged", isOn: $isChallenged)
                    .toggleStyle(.button)
                    .font(.caption.bold())
                    .tint(.red)
            }

            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach([5, 10, 15, 20, 30], id: \.self) { v in
                    Button("+\(v)") { wordScore += v }
                        .buttonStyle(.bordered)
                        .font(.caption.bold())
                }
            }

            Button(isChallenged ? "Challenged (0 pts)" : "Record \(total) pts") {
                let meta: [String: String]? = {
                    var m: [String: String] = [:]
                    if isBingo { m["bingo"] = "true" }
                    if isChallenged { m["challenged"] = "true" }
                    return m.isEmpty ? nil : m
                }()
                onSubmit(ScoreEntry(value: isChallenged ? 0 : total, metadata: meta))
                wordScore = 0
                isBingo = false
                isChallenged = false
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .tint(isChallenged ? .red : .blue)
        }
    }
}
