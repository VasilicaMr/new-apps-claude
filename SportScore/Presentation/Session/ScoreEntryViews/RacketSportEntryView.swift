import SwiftUI

struct RacketSportEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    var body: some View {
        Button {
            onSubmit(ScoreEntry(value: 1))
        } label: {
            Label("Point Won", systemImage: "checkmark.circle.fill")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
