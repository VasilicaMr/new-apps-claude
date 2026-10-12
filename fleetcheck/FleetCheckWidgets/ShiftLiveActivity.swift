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

/// Lock Screen and Dynamic Island while on shift: elapsed time, kilometers and an End button.
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
                    Text(context.state.isWaitingForGPS ? "On shift · waiting for GPS" : "On shift")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                        .font(.title2.weight(.semibold).monospacedDigit())
                    Text(kilometers(context.state.distanceKm)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(intent: EndShiftIntent()) {
                    Label("End", systemImage: "stop.fill")
                }
                .tint(.red)
            }
            .padding()
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(kilometers(context.state.distanceKm), systemImage: "road.lanes").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: EndShiftIntent()) {
                        Label("End shift", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
            } compactLeading: {
                Image(systemName: "steeringwheel").foregroundStyle(Color.accentColor)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "steeringwheel").foregroundStyle(Color.accentColor)
            }
        }
    }

    private func kilometers(_ km: Double) -> String {
        "\(km.formatted(.number.precision(.fractionLength(1)))) km"
    }
}
