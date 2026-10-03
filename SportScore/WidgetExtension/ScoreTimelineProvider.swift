import WidgetKit
import SwiftUI

struct ScoreTimelineEntry: TimelineEntry {
    let date: Date
    let widgetData: ScoreWidgetEntry
}

struct ScoreTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = ScoreTimelineEntry
    typealias Intent = SelectSessionIntent

    func placeholder(in context: Context) -> ScoreTimelineEntry {
        ScoreTimelineEntry(date: .now, widgetData: .placeholder)
    }

    func snapshot(for configuration: SelectSessionIntent, in context: Context) async -> ScoreTimelineEntry {
        let data = SharedWidgetStore.shared.latestEntry() ?? .placeholder
        return ScoreTimelineEntry(date: .now, widgetData: data)
    }

    func timeline(for configuration: SelectSessionIntent, in context: Context) async -> Timeline<ScoreTimelineEntry> {
        let data = SharedWidgetStore.shared.latestEntry() ?? .placeholder
        let entry = ScoreTimelineEntry(date: .now, widgetData: data)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }
}
