import SwiftUI
import WidgetKit
import AppIntents

struct MediumScoreWidget: View {
    let entry: ScoreTimelineEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label(entry.widgetData.sportName, systemImage: entry.widgetData.sportIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ForEach(entry.widgetData.playerScores) { ps in
                    HStack {
                        Text(ps.playerName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(ps.scoreDisplay)
                            .font(.title3.bold().monospacedDigit())
                        Button(intent: IncrementScoreIntent(
                            sessionID: entry.widgetData.sessionID,
                            playerID: ps.playerID
                        )) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(.regularMaterial, for: .widget)
    }
}
