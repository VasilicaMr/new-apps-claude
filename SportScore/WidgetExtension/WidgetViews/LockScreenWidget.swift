import SwiftUI
import WidgetKit

struct LockScreenCircularWidget: View {
    let entry: ScoreTimelineEntry

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: entry.widgetData.sportIcon)
                .font(.caption2)
            if let first = entry.widgetData.playerScores.first {
                Text(first.scoreDisplay)
                    .font(.caption.bold().monospacedDigit())
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct LockScreenRectangularWidget: View {
    let entry: ScoreTimelineEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.widgetData.sportIcon)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(entry.widgetData.playerScores.prefix(2)) { ps in
                    HStack {
                        Text(ps.playerName).font(.caption2).lineLimit(1)
                        Spacer()
                        Text(ps.scoreDisplay).font(.caption2.bold().monospacedDigit())
                    }
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}
