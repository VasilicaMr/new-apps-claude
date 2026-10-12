import WidgetKit
import SwiftUI

private struct ScoreCapWidgetEntryView: View {
    let entry: ScoreTimelineEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallScoreWidget(entry: entry)
        case .systemMedium:
            MediumScoreWidget(entry: entry)
        case .systemLarge:
            LargeScoreWidget(entry: entry)
        case .accessoryCircular:
            LockScreenCircularWidget(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularWidget(entry: entry)
        default:
            MediumScoreWidget(entry: entry)
        }
    }
}

struct ScoreCapWidget: Widget {
    // Pre-rename name: changing it would remove widgets users have already placed.
    let kind: String = "SportScoreWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSessionIntent.self,
            provider: ScoreTimelineProvider()
        ) { entry in
            ScoreCapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Live Score")
        .description("Track your active game score from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ScoreCapWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScoreCapWidget()
    }
}
