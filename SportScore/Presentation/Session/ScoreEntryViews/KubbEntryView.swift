import SwiftUI

struct KubbEntryView: View {
    let activePlayer: Player
    let onSubmit: (ScoreEntry) -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Kubbs toppled this turn")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(0...5, id: \.self) { n in
                    Button("\(n)") {
                        onSubmit(ScoreEntry(value: n, label: "kubb"))
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            Button {
                onSubmit(ScoreEntry(value: 0, label: "king", metadata: ["kingHit": "true"]))
            } label: {
                Label("\(activePlayer.name) toppled the king", systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}
