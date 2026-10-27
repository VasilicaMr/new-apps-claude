import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct FleetCheckWidgets: WidgetBundle {
    var body: some Widget {
        ShiftLiveActivity()
    }
}

/// Lock Screen and Dynamic Island while on shift: elapsed time and an End button.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "steeringwheel")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status(context.state))
                        .font(.caption).foregroundStyle(.secondary)
                    elapsed(context)
                        .font(.title2.weight(.semibold).monospacedDigit())
                }
                Spacer()
                if context.state.endDate == nil {
                    Button(intent: EndShiftIntent()) {
                        Label("End", systemImage: "stop.fill")
                    }
                    .tint(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("On shift", systemImage: "steeringwheel").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsed(context)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.endDate == nil {
                        Button(intent: EndShiftIntent()) {
                            Label("End shift", systemImage: "stop.fill").frame(maxWidth: .infinity)
                        }
                        .tint(.red)
                    } else {
                        Label("Shift ended", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            } compactLeading: {
                Image(systemName: "steeringwheel").foregroundStyle(Color.accentColor)
            } compactTrailing: {
                elapsed(context)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "steeringwheel").foregroundStyle(Color.accentColor)
            }
        }
    }

    /// A running timer while on shift; the final duration once it has ended.
    @ViewBuilder
    private func elapsed(_ context: ActivityViewContext<ShiftActivityAttributes>) -> some View {
        if let end = context.state.endDate {
            Text(Duration.seconds(end.timeIntervalSince(context.attributes.startDate)).formatted(.time(pattern: .hourMinute)))
        } else {
            Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
        }
    }

    private func status(_ state: ShiftActivityAttributes.ContentState) -> LocalizedStringKey {
        state.endDate != nil ? "Shift ended" : "On shift"
    }
}
