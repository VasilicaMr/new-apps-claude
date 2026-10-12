import Foundation

enum Severity: String, Codable, Sendable, Comparable, CaseIterable {
    case info, warning, critical

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .critical: 2
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rank < rhs.rank }
}

enum AlertType: String, Codable, Sendable {
    case diagnosticCode, batteryLow, lowFuel, harshBraking, speeding, geofenceExit, geofenceEnter
    case maintenanceDue, idle, engineTemperature
}

struct FleetAlert: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let vehicleId: String
    let timestamp: Date
    let severity: Severity
    let type: AlertType
    let message: String
    let acknowledged: Bool
}

enum GeofenceType: String, Codable, Sendable {
    case depot, client, restricted
}

struct Geofence: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: GeofenceType
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double

    var center: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }

    func contains(_ coordinate: GeoCoordinate) -> Bool {
        center.distance(to: coordinate) <= radiusMeters
    }
}
