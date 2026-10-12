import Foundation

struct Company: Codable, Sendable, Equatable {
    struct HomeBase: Codable, Sendable, Equatable {
        let name: String
        let latitude: Double
        let longitude: Double

        var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
    }

    /// Server-side tracking defaults. The app can override the threshold locally in Settings.
    struct TrackingPolicy: Codable, Sendable, Equatable {
        let distanceThresholdMeters: Double
        let heartbeatSeconds: Double
        let desiredAccuracyMeters: Double
    }

    let id: String
    let name: String
    let currencyCode: String
    let timezone: String
    /// Last day covered by the analytics feeds; all "last N days" windows end here.
    let dataAsOf: Date
    let homeBase: HomeBase
    let trackingPolicy: TrackingPolicy
}
