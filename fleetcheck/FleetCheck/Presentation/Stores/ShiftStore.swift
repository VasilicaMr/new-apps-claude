import ActivityKit
import Foundation
import Observation
import SwiftData

/// Runs the current shift: its clock and the Live Activity. There is no GPS (it drains the battery);
/// kilometers come from the trip screenshots the driver adds afterwards.
@MainActor
@Observable
final class ShiftStore {
    private(set) var activeShift: Shift?
    /// Set when a shift ends so the UI can ask "How much did you earn?".
    var shiftAwaitingEarnings: Shift?

    private let context: ModelContext
    private var activity: Activity<ShiftActivityAttributes>?
    private var endingActivity: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
    }

    var isOnShift: Bool { activeShift != nil }

    /// Re-attaches to a shift that was running when the app was closed or terminated by iOS.
    func resumeIfNeeded() {
        guard activeShift == nil else { return }
        var descriptor = FetchDescriptor<Shift>(predicate: #Predicate { $0.end == nil }, sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let open = try? context.fetch(descriptor).first else { return }
        attach(to: open)
    }

    func startShift() {
        guard activeShift == nil else { return }
        let shift = Shift(start: .now)
        context.insert(shift)
        try? context.save()
        attach(to: shift)
    }

    /// Ends the running shift and returns it. Its kilometers arrive with the earnings screenshots.
    @discardableResult
    func endShift() -> Shift? {
        guard let shift = activeShift else { return nil }
        shift.end = .now
        try? context.save()

        endActivity()
        activeShift = nil
        shiftAwaitingEarnings = shift
        return shift
    }

    /// Short summary used by Siri and the Live Activity button. Returns once the Live Activity
    /// has really ended, because the app may be suspended right after.
    func endShiftSummary() async -> String? {
        let shift = endShift()
        await endingActivity?.value
        // A card left over from a relaunch or an earlier shift would still show an End button.
        for leftover in Activity<ShiftActivityAttributes>.activities where leftover.content.state.endDate == nil {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
        guard let shift else { return nil }
        let hours = Formatters.duration(shift.duration)
        return String(localized: "Shift ended after \(hours). Open DriveCap and add the screenshots of your trips.")
    }

    private func attach(to shift: Shift) {
        activeShift = shift
        startActivity(for: shift)
    }

    // MARK: - Live Activity

    private func startActivity(for shift: Shift) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Reuse the card if the app was relaunched mid-shift.
        if let existing = Activity<ShiftActivityAttributes>.activities.first(where: { $0.attributes.startDate == shift.start }) {
            activity = existing
            return
        }
        for stale in Activity<ShiftActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
        activity = try? Activity.request(
            attributes: ShiftActivityAttributes(startDate: shift.start),
            content: ActivityContent(state: .init(endDate: nil), staleDate: nil))
    }

    /// Shows "Shift ended" with the totals for a moment, then removes the card. The default policy
    /// would leave it on the Lock Screen for hours, still looking like a running shift.
    private func endActivity() {
        guard let activity else { return }
        let state = ShiftActivityAttributes.ContentState(endDate: .now)
        endingActivity = Task {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 120))
        }
        self.activity = nil
    }
}
