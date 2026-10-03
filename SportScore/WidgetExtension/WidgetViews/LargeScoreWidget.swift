import SwiftUI
import WidgetKit

struct LargeScoreWidget: View {
    let entry: ScoreTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(entry.widgetData.sportName, systemImage: entry.widgetData.sportIcon)
                .font(.headline)

            Divider()

            ForEach(entry.widgetData.playerScores) { ps in
                HStack {
                    Text(ps.playerName).font(.body)
                    Spacer()
                    Text(ps.scoreDisplay)
                        .font(.title2.bold().monospacedDigit())
                    Button(intent: IncrementScoreIntent(
                        sessionID: entry.widgetData.sessionID,
                        playerID: ps.playerID
                    )) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(.vertical, 2)
            }

            Spacer()

            Text(entry.date.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .containerBackground(.regularMaterial, for: .widget)
    }
}
