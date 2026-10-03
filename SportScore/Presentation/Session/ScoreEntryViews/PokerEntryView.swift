import SwiftUI

struct PokerEntryView: View {
    let activePlayer: Player
    /// Chips the player currently has; a loss can't exceed it.
    var stack: Int = .max
    let onSubmit: (ScoreEntry) -> Void

    @State private var delta: Int = 0
    @State private var isWin: Bool = true

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Stack change for \(activePlayer.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: AppTheme.Spacing.sm) {
                Picker("Direction", selection: $isWin) {
                    Text("Win (+)").tag(true)
                    Text("Loss (−)").tag(false)
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 20) {
                Button { delta = max(0, delta - 100) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                Text("\(isWin ? "+" : "−")\(delta)")
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isWin ? .green : .red)
                    .contentTransition(.numericText())
                    .animation(.bouncy, value: delta)
                    .frame(minWidth: 100)

                Button { delta += 100 } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach([100, 500, 1000, 2500], id: \.self) { v in
                    Button("\(v)") { delta = v }
                        .buttonStyle(.bordered)
                        .font(.caption.bold())
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Busted out") {
                    onSubmit(ScoreEntry(value: -stack, label: "eliminated"))
                    delta = 0
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(stack == .max || stack <= 0)

                Button("Record") {
                    let signed = isWin ? delta : -min(delta, stack)
                    onSubmit(ScoreEntry(value: signed))
                    delta = 0
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(delta == 0)
            }
        }
    }
}
