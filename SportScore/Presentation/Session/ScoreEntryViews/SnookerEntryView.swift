import SwiftUI

struct SnookerEntryView: View {
    let activePlayer: Player
    let onSubmit: (ScoreEntry) -> Void

    private let balls: [(name: String, value: Int, color: Color)] = [
        ("Red", 1, .red),
        ("Yellow", 2, .yellow),
        ("Green", 3, .green),
        ("Brown", 4, .brown),
        ("Blue", 5, .blue),
        ("Pink", 6, .pink),
        ("Black", 7, .black),
    ]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: 0) {
                ForEach(balls, id: \.value) { ball in
                    Button {
                        onSubmit(ScoreEntry(value: ball.value, metadata: ["ball": ball.name.lowercased()]))
                    } label: {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(ball.color)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.3), lineWidth: 1))
                            Text("\(ball.value)")
                                .font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(ball.name), \(ball.value)")
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Miss / End break") {
                    onSubmit(ScoreEntry(value: 0, metadata: ["miss": "true"]))
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(4...7, id: \.self) { penalty in
                        Button("Foul — \(penalty) to opponent") {
                            onSubmit(ScoreEntry(value: 0, metadata: ["foul": "\(penalty)"]))
                        }
                    }
                } label: {
                    Text("Foul…")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .font(.callout)

            Button {
                onSubmit(ScoreEntry(value: 0, label: "frameWin"))
            } label: {
                Label("\(activePlayer.name) won the frame", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
