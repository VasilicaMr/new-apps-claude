import Foundation

/// Latest reading reported by a vehicle's telematics box (OBD-II / CAN dongle).
struct TelemetrySnapshot: Codable, Sendable, Hashable {
    let vehicleId: String
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let speedKmh: Double
    let headingDegrees: Double
    let ignitionOn: Bool
    let fuelLevelPercent: Double
    let batteryVoltage: Double
    let engineTemperatureC: Double
    let odometerKm: Double
    /// OBD-II diagnostic trouble codes currently active, e.g. "P0401".
    let diagnosticCodes: [String]

    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
}

/// One aggregated day of usage for one vehicle. Feeds every financial and usage analysis.
struct DailyMetric: Codable, Sendable, Hashable {
    let vehicleId: String
    let date: Date
    let distanceKm: Double
    let drivingMinutes: Double
    let idleMinutes: Double
    /// Litres of fuel or kWh, depending on the vehicle's `FuelType`.
    let energyUsed: Double
    let energyCost: Double
    let revenue: Double
    let jobsCompleted: Int
    let harshBrakingEvents: Int
    let harshAccelerationEvents: Int
    let speedingEvents: Int

    var isActive: Bool { distanceKm > 0 }
    var harshEvents: Int { harshBrakingEvents + harshAccelerationEvents + speedingEvents }
}

struct Trip: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let vehicleId: String
    let driverId: String
    let startTime: Date
    let endTime: Date
    let startAddress: String
    let endAddress: String
    let distanceKm: Double
    let revenue: Double
    let averageSpeedKmh: Double
    let maxSpeedKmh: Double

    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
}
