import Foundation
import Observation

/// Consumes the live position feed, keeps the latest position per vehicle for the map,
/// and runs every sample through `LocationChangeFilter` so only meaningful moves are stored and uploaded.
@MainActor
@Observable
final class LiveTrackingStore {
    private(set) var positions: [String: VehiclePosition] = [:]
    private(set) var events: [LocationEvent] = []
    private(set) var samplesReceived = 0
    private(set) var eventsReported = 0
    private(set) var isRunning = false
    private(set) var lastError: String?

    var thresholdMeters: Double {
        didSet { filter.thresholdMeters = thresholdMeters }
    }

    private let dependencies: AppDependencies
    private var filter: LocationChangeFilter
    private var pendingUpload: [LocationEvent] = []
    private var streamTask: Task<Void, Never>?
    private let uploadBatchSize = 10
    private let maxEventsKept = 300

    init(dependencies: AppDependencies, thresholdMeters: Double = 50) {
        self.dependencies = dependencies
        self.thresholdMeters = thresholdMeters
        filter = LocationChangeFilter(thresholdMeters: thresholdMeters)
    }

    /// Share of raw samples the filter discarded — the battery/data savings.
    var suppressedShare: Double {
        samplesReceived > 0 ? 1 - Double(eventsReported) / Double(samplesReceived) : 0
    }

    func events(for vehicleId: String) -> [LocationEvent] {
        events.filter { $0.vehicleId == vehicleId }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        streamTask = Task { [weak self, dependencies] in
            do {
                let routes = try await dependencies.repository.liveRoutes()
                let stream = dependencies.makePositionStream(routes).positions()
                for await position in stream {
                    self?.handle(position)
                }
            } catch {
                self?.lastError = error.localizedDescription
                self?.isRunning = false
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isRunning = false
        flush()
    }

    private func handle(_ position: VehiclePosition) {
        samplesReceived += 1
        positions[position.vehicleId] = position
        guard let event = filter.evaluate(position) else { return }
        eventsReported += 1
        events.insert(event, at: 0)
        if events.count > maxEventsKept { events.removeLast(events.count - maxEventsKept) }
        pendingUpload.append(event)
        if pendingUpload.count >= uploadBatchSize { flush() }
    }

    /// Batching uploads (instead of one request per event) is another big battery/data win on phones.
    private func flush() {
        guard !pendingUpload.isEmpty else { return }
        let batch = pendingUpload
        pendingUpload.removeAll()
        Task { [repository = dependencies.repository] in
            do { try await repository.report(batch) } catch { self.lastError = error.localizedDescription }
        }
    }
}
