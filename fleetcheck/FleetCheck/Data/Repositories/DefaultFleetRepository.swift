import Foundation

struct DefaultFleetRepository: FleetRepository {
    let client: any APIClient
    /// How much history the analytics screens can look back on.
    var historyDays = 365

    func loadSnapshot() async throws -> FleetSnapshot {
        // Company first: its `dataAsOf` anchors the date-ranged requests.
        let company = try await client.send(.company, as: Company.self)
        let range = DateRange.lastDays(historyDays, endingOn: company.dataAsOf)

        async let vehicles = client.send(.vehicles, as: [Vehicle].self)
        async let drivers = client.send(.drivers, as: [Driver].self)
        async let telemetry = client.send(.latestTelemetry, as: [TelemetrySnapshot].self)
        async let metrics = client.send(.dailyMetrics(from: range.start, to: range.end), as: [DailyMetric].self)
        async let trips = client.send(.trips(from: range.start, to: range.end), as: [Trip].self)
        async let maintenance = client.send(.maintenanceRecords, as: [MaintenanceRecord].self)
        async let expenses = client.send(.expenses(from: range.start, to: range.end), as: [Expense].self)
        async let models = client.send(.valuationModels, as: [ValuationModel].self)
        async let alerts = client.send(.alerts, as: [FleetAlert].self)
        async let geofences = client.send(.geofences, as: [Geofence].self)

        return try await FleetSnapshot(
            company: company, vehicles: vehicles, drivers: drivers, telemetry: telemetry,
            dailyMetrics: metrics, trips: trips, maintenance: maintenance, expenses: expenses,
            valuationModels: models, alerts: alerts, geofences: geofences)
    }

    func liveRoutes() async throws -> [LiveRoute] {
        try await client.send(.liveRoutes, as: [LiveRoute].self)
    }

    func report(_ events: [LocationEvent]) async throws -> LocationEventAck {
        try await client.send(.reportLocationEvents(events), as: LocationEventAck.self)
    }
}
