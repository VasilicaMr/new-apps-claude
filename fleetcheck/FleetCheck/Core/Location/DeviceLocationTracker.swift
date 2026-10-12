import CoreLocation
import Foundation

/// Battery-friendly GPS for a driver's phone ("Driver mode").
///
/// Battery tips applied here:
/// - `distanceFilter` = threshold (default 50 m): CoreLocation wakes us only after real movement.
/// - `kCLLocationAccuracyHundredMeters`: uses Wi-Fi/cell + occasional GPS instead of continuous GPS.
/// - `pausesLocationUpdatesAutomatically`: iOS stops updates while the car is parked.
/// - `.automotiveNavigation` activity type: tells iOS the device is in a vehicle on roads.
/// - Optional significant-change mode (~500 m, cell-tower based) for an "ultra low power" setting.
@MainActor
final class DeviceLocationTracker: NSObject {
    enum Mode: Sendable { case standard, significantChangesOnly }

    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocation>.Continuation?
    private(set) var authorization: CLAuthorizationStatus

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = true
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        // Ask for When In Use first; iOS offers the "Always" upgrade later, which converts much better.
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if authorization == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    func start(distanceFilter: CLLocationDistance, mode: Mode = .standard) -> AsyncStream<CLLocation> {
        stop()
        let (stream, continuation) = AsyncStream.makeStream(of: CLLocation.self, bufferingPolicy: .bufferingNewest(20))
        self.continuation = continuation
        requestPermission()

        manager.distanceFilter = distanceFilter
        if authorization == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        switch mode {
        case .standard: manager.startUpdatingLocation()
        case .significantChangesOnly: manager.startMonitoringSignificantLocationChanges()
        }
        return stream
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.allowsBackgroundLocationUpdates = false
        continuation?.finish()
        continuation = nil
    }
}

extension DeviceLocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Drop stale cached fixes and very inaccurate ones (> 200 m).
        let usable = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 200 && abs($0.timestamp.timeIntervalSinceNow) < 60 }
        Task { @MainActor in
            usable.forEach { self.continuation?.yield($0) }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown is transient; CoreLocation keeps trying on its own.
    }
}
