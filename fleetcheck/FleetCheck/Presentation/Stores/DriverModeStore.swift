import CoreLocation
import Foundation
import Observation

/// Turns this iPhone into a tracker for one vehicle — useful before buying telematics boxes,
/// or for drivers who use their own car.
@MainActor
@Observable
final class DriverModeStore {
    static let deviceVehicleId = "this-device"

    private(set) var isTracking = false
    private(set) var lastLocation: CLLocation?
    private(set) var events: [LocationEvent] = []
    private(set) var rawFixes = 0

    private let repository: any FleetRepository
    private let tracker = DeviceLocationTracker()
    private var filter = LocationChangeFilter()
    private var task: Task<Void, Never>?

    init(repository: any FleetRepository) {
        self.repository = repository
    }

    var authorizationDescription: String {
        switch tracker.authorization {
        case .authorizedAlways: "Always (background tracking on)"
        case .authorizedWhenInUse: "While using the app"
        case .denied, .restricted: "Denied — enable in Settings"
        case .notDetermined: "Not asked yet"
        @unknown default: "Unknown"
        }
    }

    func start(thresholdMeters: Double, lowPower: Bool) {
        stop()
        filter = LocationChangeFilter(thresholdMeters: thresholdMeters)
        isTracking = true
        let stream = tracker.start(distanceFilter: thresholdMeters, mode: lowPower ? .significantChangesOnly : .standard)
        task = Task { [weak self] in
            for await location in stream {
                self?.handle(location)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        tracker.stop()
        isTracking = false
    }

    private func handle(_ location: CLLocation) {
        rawFixes += 1
        lastLocation = location
        let position = VehiclePosition(
            vehicleId: Self.deviceVehicleId,
            coordinate: GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            speedKmh: max(0, location.speed) * 3.6, timestamp: location.timestamp)
        guard let event = filter.evaluate(position) else { return }
        events.insert(event, at: 0)
        Task { [repository] in try? await repository.report([event]) }
    }
}
