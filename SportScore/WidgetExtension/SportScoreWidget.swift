import WidgetKit
import SwiftUI

private struct SportScoreWidgetEntryView: View {
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

struct SportScoreWidget: Widget {
    let kind: String = "SportScoreWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSessionIntent.self,
            provider: ScoreTimelineProvider()
        ) { entry in
            SportScoreWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Live Score")
        .description("Track your active game score from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct SportScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        SportScoreWidget()
    }
}
