import WidgetKit
import SwiftUI

// MARK: - Shared snapshot (mirrors WidgetDataWriter.WidgetSnapshot in the main target)

private struct WidgetSnapshot: Codable {
    var thoughtCount: Int
    var expenseCount: Int
    var taskTotalCount: Int
    var taskOpenCount: Int
    var totalSpentToday: Double
    var currency: String
    var latestCapture: String

    var totalCaptures: Int { thoughtCount + expenseCount + taskTotalCount }

    static let placeholder = WidgetSnapshot(
        thoughtCount: 3, expenseCount: 2, taskTotalCount: 5,
        taskOpenCount: 2, totalSpentToday: 66.50,
        currency: "EUR", latestCapture: "Call dentist tomorrow"
    )

    static func load() -> WidgetSnapshot {
        guard
            let data = UserDefaults(suiteName: "group.com.universalcap")?.data(forKey: "widgetSnapshot"),
            let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot(thoughtCount: 0, expenseCount: 0, taskTotalCount: 0,
                                     taskOpenCount: 0, totalSpentToday: 0, currency: "EUR", latestCapture: "") }
        return snap
    }
}

// MARK: - Timeline

private struct CaptureEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry {
        .init(date: .now, snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(.init(date: .now, snapshot: .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        let entry = CaptureEntry(date: .now, snapshot: .load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Colours

private let bgGradient = LinearGradient(
    colors: [
        Color(red: 0.20, green: 0.10, blue: 0.48),
        Color(red: 0.10, green: 0.18, blue: 0.58)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - Small widget

private struct SmallView: View {
    let snap: WidgetSnapshot

    var body: some View {
        ZStack(alignment: .leading) {
            bgGradient

            // Decorative blurred circle
            Circle()
                .fill(Color.purple.opacity(0.35))
                .frame(width: 100)
                .blur(radius: 30)
                .offset(x: 60, y: -40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2.bold())
                    Text("UniversalCap")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Text("\(snap.totalCaptures)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)

                Text(snap.totalCaptures == 1 ? "capture" : "captures")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
        }
    }
}

// MARK: - Medium widget

private struct MediumView: View {
    let snap: WidgetSnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            bgGradient

            Circle()
                .fill(Color.blue.opacity(0.30))
                .frame(width: 140)
                .blur(radius: 40)
                .offset(x: 260, y: -20)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                    Text("UniversalCap")
                        .font(.caption.bold())
                    Spacer()
                    Text(Date(), style: .date)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .foregroundStyle(.white.opacity(0.6))

                Divider().overlay(.white.opacity(0.15))

                // Stats
                HStack(spacing: 0) {
                    PillStat(value: "\(snap.thoughtCount)",
                             label: "thoughts",
                             icon: "lightbulb.fill",
                             tint: Color(red: 0.72, green: 0.45, blue: 1.0))
                    PillStat(value: "\(snap.currency) \(formatted(snap.totalSpentToday))",
                             label: "today",
                             icon: "dollarsign.circle.fill",
                             tint: Color(red: 0.35, green: 0.90, blue: 0.55))
                    PillStat(value: "\(snap.taskOpenCount)",
                             label: "open tasks",
                             icon: "checkmark.circle.fill",
                             tint: Color(red: 0.35, green: 0.65, blue: 1.0))
                }

                // Latest capture
                if !snap.latestCapture.isEmpty {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.35))
                            .frame(width: 3)
                        Text(snap.latestCapture)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.80))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
        }
    }

    private func formatted(_ value: Double) -> String {
        value == 0 ? "0" : String(format: value < 100 ? "%.1f" : "%.0f", value)
    }
}

private struct PillStat: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Accessory circular (lock screen)

private struct CircularView: View {
    let snap: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text("\(snap.totalCaptures)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

// MARK: - Entry view

private struct EntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CaptureEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(snap: entry.snapshot)
        case .systemMedium:
            MediumView(snap: entry.snapshot)
        case .accessoryCircular:
            CircularView(snap: entry.snapshot)
        default:
            SmallView(snap: entry.snapshot)
        }
    }
}

// MARK: - Widget

struct UniversalCapWidget: Widget {
    let kind = "UniversalCapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaptureProvider()) { entry in
            EntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("UniversalCap")
        .description("Today's captures at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - Bundle entry point

@main
struct UniversalCapWidgetBundle: WidgetBundle {
    var body: some Widget {
        UniversalCapWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    UniversalCapWidget()
} timeline: {
    CaptureEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    UniversalCapWidget()
} timeline: {
    CaptureEntry(date: .now, snapshot: .placeholder)
}
