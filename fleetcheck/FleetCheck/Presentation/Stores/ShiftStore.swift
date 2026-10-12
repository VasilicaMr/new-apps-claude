import ActivityKit
import Foundation
import Observation
import SwiftData

/// Runs the current shift: GPS tracking, distance, saving the route, and the Live Activity.
@MainActor
@Observable
final class ShiftStore {
    private(set) var activeShift: Shift?
    private(set) var distanceMeters: Double = 0
    private(set) var movingSeconds: Double = 0
    private(set) var route: [RoutePoint] = []
    private(set) var gpsStatus: ShiftLocationTracker.Status = .idle
    /// Set when a shift ends so the UI can ask "How much did you earn?".
    var shiftAwaitingEarnings: Shift?

    private let context: ModelContext
    private let tracker = ShiftLocationTracker()
    private var accumulator = DistanceAccumulator()
    private var trackingTask: Task<Void, Never>?
    private var activity: Activity<ShiftActivityAttributes>?
    private var unsavedPoints = 0
    private var lastActivityUpdate = Date.distantPast

    init(context: ModelContext) {
        self.context = context
        tracker.onStatusChange = { [weak self] status in
            self?.gpsStatus = status
            self?.updateActivity(force: true)
        }
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

    /// Ends the running shift, adds its kilometers to the car's odometer and returns it.
    @discardableResult
    func endShift() -> Shift? {
        guard let shift = activeShift else { return nil }
        trackingTask?.cancel()
        trackingTask = nil
        tracker.stop()

        shift.end = .now
        shift.distanceMeters = accumulator.distanceMeters
        shift.movingSeconds = accumulator.movingSeconds
        shift.route = route
        let car = context.car()
        car.odometerKm += shift.distanceKm
        car.odometerUpdatedAt = .now
        try? context.save()

        endActivity()
        activeShift = nil
        shiftAwaitingEarnings = shift
        return shift
    }

    /// Short summary used by Siri and the Live Activity button.
    func endShiftSummary() -> String? {
        guard let shift = endShift() else { return nil }
        let hours = Formatters.duration(shift.duration)
        return "Shift ended: \(shift.distanceKm.kilometers) in \(hours). Open FleetCheck to add what you earned."
    }

    private func attach(to shift: Shift) {
        activeShift = shift
        route = shift.route
        accumulator = DistanceAccumulator(distanceMeters: shift.distanceMeters, movingSeconds: shift.movingSeconds, lastPoint: route.last)
        distanceMeters = accumulator.distanceMeters
        movingSeconds = accumulator.movingSeconds
        startActivity(for: shift)

        let samples = tracker.start()
        trackingTask = Task { [weak self] in
            for await sample in samples {
                self?.handle(sample)
            }
        }
    }

    private func handle(_ sample: LocationSample) {
        guard let shift = activeShift, let point = accumulator.add(sample) else { return }
        route.append(point)
        distanceMeters = accumulator.distanceMeters
        movingSeconds = accumulator.movingSeconds
        unsavedPoints += 1
        // Save regularly so a crash or iOS terminating the app loses at most a few hundred meters.
        if unsavedPoints >= 10 {
            shift.distanceMeters = distanceMeters
            shift.movingSeconds = movingSeconds
            shift.route = route
            try? context.save()
            unsavedPoints = 0
        }
        updateActivity()
    }

    // MARK: - Live Activity

    private func startActivity(for shift: Shift) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Reuse the card if the app was relaunched mid-shift.
        if let existing = Activity<ShiftActivityAttributes>.activities.first(where: { $0.attributes.startDate == shift.start }) {
            activity = existing
            updateActivity(force: true)
            return
        }
        for stale in Activity<ShiftActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
        activity = try? Activity.request(
            attributes: ShiftActivityAttributes(startDate: shift.start),
            content: ActivityContent(state: activityState, staleDate: nil))
    }

    private var activityState: ShiftActivityAttributes.ContentState {
        .init(distanceKm: distanceMeters / 1000, isWaitingForGPS: gpsStatus != .tracking)
    }

    private func updateActivity(force: Bool = false) {
        guard let activity, force || Date.now.timeIntervalSince(lastActivityUpdate) >= 20 else { return }
        lastActivityUpdate = .now
        let state = activityState
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func endActivity() {
        guard let activity else { return }
        let state = activityState
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default) }
        self.activity = nil
    }
}
