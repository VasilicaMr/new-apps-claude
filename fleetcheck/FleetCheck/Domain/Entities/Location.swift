import Foundation

/// Framework-free coordinate so the domain layer doesn't depend on CoreLocation.
struct GeoCoordinate: Codable, Sendable, Hashable {
    let latitude: Double
    let longitude: Double

    /// Great-circle distance in meters (haversine).
    func distance(to other: GeoCoordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let h = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}

/// A live position sample, from a telematics box or a driver's phone.
struct VehiclePosition: Sendable, Hashable {
    let vehicleId: String
    let coordinate: GeoCoordinate
    let speedKmh: Double
    let timestamp: Date
}

/// A position that passed the distance filter and is worth storing/sending to the backend.
struct LocationEvent: Codable, Sendable, Identifiable, Hashable {
    enum Reason: String, Codable, Sendable {
        case firstFix, movedBeyondThreshold, heartbeat
    }

    let id: UUID
    let vehicleId: String
    let coordinate: GeoCoordinate
    let timestamp: Date
    /// Distance from the previously reported event; nil for the first fix.
    let distanceFromPreviousMeters: Double?
    let reason: Reason
}

struct LocationEventAck: Codable, Sendable {
    let accepted: Bool
    let serverTime: Date
    let nextHeartbeatSeconds: Double
}

/// Pre-recorded path used by the simulated live feed (mock backend only).
struct LiveRoute: Codable, Sendable {
    let vehicleId: String
    let tickSeconds: Double
    /// `[latitude, longitude]` pairs.
    let points: [[Double]]
}
