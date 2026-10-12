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

/// A raw GPS fix from the phone.
struct LocationSample: Sendable, Hashable {
    let coordinate: GeoCoordinate
    let timestamp: Date
    /// Radius of uncertainty in meters; negative means invalid.
    let horizontalAccuracy: Double
}

/// A point of a shift's route that passed the filter and is stored.
struct RoutePoint: Codable, Sendable, Hashable {
    let coordinate: GeoCoordinate
    let timestamp: Date

    /// Compact storage: `[lat, lon, unixTime]` triplets, ~3x smaller than keyed JSON.
    static func encode(_ points: [RoutePoint]) -> Data {
        let flat = points.flatMap { [$0.coordinate.latitude, $0.coordinate.longitude, $0.timestamp.timeIntervalSince1970] }
        return (try? JSONEncoder().encode(flat)) ?? Data()
    }

    static func decode(_ data: Data) -> [RoutePoint] {
        guard let flat = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return stride(from: 0, to: flat.count - 2, by: 3).map {
            RoutePoint(coordinate: GeoCoordinate(latitude: flat[$0], longitude: flat[$0 + 1]),
                       timestamp: Date(timeIntervalSince1970: flat[$0 + 2]))
        }
    }
}
