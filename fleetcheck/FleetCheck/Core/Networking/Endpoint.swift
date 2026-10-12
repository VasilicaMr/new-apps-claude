import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST"
}

/// Every backend call the app makes. Each case documents its REST route and the local
/// JSON file that `MockAPIClient` serves for it (FleetCheck/Resources/MockData/<file>.json).
enum Endpoint: Sendable {
    /// GET /v1/company → company.json
    case company
    /// GET /v1/vehicles → vehicles.json
    case vehicles
    /// GET /v1/drivers → drivers.json
    case drivers
    /// GET /v1/telemetry/latest → telemetry_latest.json
    case latestTelemetry
    /// GET /v1/metrics/daily?from=&to= → daily_metrics.json
    case dailyMetrics(from: Date, to: Date)
    /// GET /v1/trips?from=&to= → trips.json
    case trips(from: Date, to: Date)
    /// GET /v1/maintenance/records → maintenance_records.json
    case maintenanceRecords
    /// GET /v1/expenses?from=&to= → expenses.json
    case expenses(from: Date, to: Date)
    /// GET /v1/valuation/models → valuation_models.json
    case valuationModels
    /// GET /v1/alerts → alerts.json
    case alerts
    /// GET /v1/geofences → geofences.json
    case geofences
    /// GET /v1/simulation/routes → live_routes.json (mock-only helper for the live map)
    case liveRoutes
    /// POST /v1/location-events → location_event_ack.json
    case reportLocationEvents([LocationEvent])

    var method: HTTPMethod {
        if case .reportLocationEvents = self { return .post }
        return .get
    }

    var path: String {
        switch self {
        case .company: "/v1/company"
        case .vehicles: "/v1/vehicles"
        case .drivers: "/v1/drivers"
        case .latestTelemetry: "/v1/telemetry/latest"
        case .dailyMetrics: "/v1/metrics/daily"
        case .trips: "/v1/trips"
        case .maintenanceRecords: "/v1/maintenance/records"
        case .expenses: "/v1/expenses"
        case .valuationModels: "/v1/valuation/models"
        case .alerts: "/v1/alerts"
        case .geofences: "/v1/geofences"
        case .liveRoutes: "/v1/simulation/routes"
        case .reportLocationEvents: "/v1/location-events"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .dailyMetrics(from, to), let .trips(from, to), let .expenses(from, to):
            [URLQueryItem(name: "from", value: from.formatted(FleetJSON.dayFormat)),
             URLQueryItem(name: "to", value: to.formatted(FleetJSON.dayFormat))]
        default:
            []
        }
    }

    var body: (any Encodable & Sendable)? {
        if case let .reportLocationEvents(events) = self { return events }
        return nil
    }

    var mockResource: String {
        switch self {
        case .company: "company"
        case .vehicles: "vehicles"
        case .drivers: "drivers"
        case .latestTelemetry: "telemetry_latest"
        case .dailyMetrics: "daily_metrics"
        case .trips: "trips"
        case .maintenanceRecords: "maintenance_records"
        case .expenses: "expenses"
        case .valuationModels: "valuation_models"
        case .alerts: "alerts"
        case .geofences: "geofences"
        case .liveRoutes: "live_routes"
        case .reportLocationEvents: "location_event_ack"
        }
    }
}
