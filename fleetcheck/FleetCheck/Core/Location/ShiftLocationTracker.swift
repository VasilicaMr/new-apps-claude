import CoreLocation
import Foundation

/// GPS for a running shift, built on the modern CoreLocation APIs:
///
/// - `CLLocationUpdate.liveUpdates(.automotiveNavigation)` streams fixes tuned for driving.
/// - `CLBackgroundActivitySession` keeps updates flowing with the app in the background using only
///   "While Using" permission (the blue location pill shows the driver it is on), so we never need "Always".
/// - If iOS terminates the app mid-shift, `ShiftStore.resumeIfNeeded()` restarts this at launch.
///
/// Kilometer accuracy matters more than battery here (drivers' phones are usually charging),
/// and `DistanceAccumulator` throws away most fixes before anything is stored.
@MainActor
final class ShiftLocationTracker {
    enum Status: Equatable, Sendable {
        case idle, waitingForFix, tracking, denied, unavailable
    }

    private(set) var status: Status = .idle
    var onStatusChange: ((Status) -> Void)?

    private var backgroundSession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?
    private var task: Task<Void, Never>?

    func start() -> AsyncStream<LocationSample> {
        stop()
        let (stream, continuation) = AsyncStream.makeStream(of: LocationSample.self, bufferingPolicy: .bufferingNewest(100))
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundSession = CLBackgroundActivitySession()
        setStatus(.waitingForFix)

        task = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    guard let self, !Task.isCancelled else { break }
                    if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                        self.setStatus(.denied)
                        continue
                    }
                    if update.locationUnavailable {
                        self.setStatus(.unavailable)
                        continue
                    }
                    guard let location = update.location else { continue }
                    self.setStatus(.tracking)
                    continuation.yield(LocationSample(
                        coordinate: GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                        timestamp: location.timestamp,
                        horizontalAccuracy: location.horizontalAccuracy))
                }
            } catch {
                self?.setStatus(.unavailable)
            }
            continuation.finish()
        }
        return stream
    }

    func stop() {
        task?.cancel()
        task = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
        setStatus(.idle)
    }

    private func setStatus(_ new: Status) {
        guard new != status else { return }
        status = new
        onStatusChange?(new)
    }
}
