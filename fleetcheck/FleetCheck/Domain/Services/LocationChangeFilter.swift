import Foundation

/// Decides which position samples are worth keeping.
///
/// A sample is reported when the vehicle has moved at least `thresholdMeters` from the last
/// *reported* point (not the last sample, so slow drift still adds up), or when the
/// heartbeat interval elapsed so the backend knows a parked vehicle is still online.
///
/// Combined with a coarse GPS accuracy on the phone, this keeps battery and data usage low
/// while still giving a useful breadcrumb trail.
struct LocationChangeFilter: Sendable {
    var thresholdMeters: Double
    var heartbeat: TimeInterval
    private var lastReported: [String: LocationEvent] = [:]

    init(thresholdMeters: Double = 50, heartbeat: TimeInterval = 300) {
        self.thresholdMeters = thresholdMeters
        self.heartbeat = heartbeat
    }

    mutating func evaluate(_ position: VehiclePosition) -> LocationEvent? {
        guard let previous = lastReported[position.vehicleId] else {
            return record(position, distance: nil, reason: .firstFix)
        }
        let distance = previous.coordinate.distance(to: position.coordinate)
        if distance >= thresholdMeters {
            return record(position, distance: distance, reason: .movedBeyondThreshold)
        }
        if position.timestamp.timeIntervalSince(previous.timestamp) >= heartbeat {
            return record(position, distance: distance, reason: .heartbeat)
        }
        return nil
    }

    mutating func reset() { lastReported.removeAll() }

    private mutating func record(_ position: VehiclePosition, distance: Double?, reason: LocationEvent.Reason) -> LocationEvent {
        let event = LocationEvent(id: UUID(), vehicleId: position.vehicleId, coordinate: position.coordinate,
                                  timestamp: position.timestamp, distanceFromPreviousMeters: distance, reason: reason)
        lastReported[position.vehicleId] = event
        return event
    }
}
