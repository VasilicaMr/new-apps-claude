import SwiftUI
import WidgetKit

struct SmallScoreWidget: View {
    let entry: ScoreTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(entry.widgetData.sportName, systemImage: entry.widgetData.sportIcon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ForEach(entry.widgetData.playerScores.prefix(2)) { ps in
                HStack {
                    Text(ps.playerName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(ps.scoreDisplay)
                        .font(.caption.bold().monospacedDigit())
                }
            }
        }
        .padding(12)
        .containerBackground(.regularMaterial, for: .widget)
    }
}
