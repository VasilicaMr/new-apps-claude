import Foundation

/// Everything the analytics need, loaded in one go. Indexes are built once so views
/// and services can look things up by vehicle without re-filtering arrays.
struct FleetSnapshot: Sendable {
    let company: Company
    let vehicles: [Vehicle]
    let drivers: [Driver]
    let telemetry: [TelemetrySnapshot]
    let dailyMetrics: [DailyMetric]
    let trips: [Trip]
    let maintenance: [MaintenanceRecord]
    let expenses: [Expense]
    let valuationModels: [ValuationModel]
    let alerts: [FleetAlert]
    let geofences: [Geofence]

    private let metricsByVehicle: [String: [DailyMetric]]
    private let maintenanceByVehicle: [String: [MaintenanceRecord]]
    private let expensesByVehicle: [String: [Expense]]
    private let tripsByVehicle: [String: [Trip]]
    private let telemetryByVehicle: [String: TelemetrySnapshot]
    private let driversById: [String: Driver]
    private let modelsBySegment: [VehicleSegment: ValuationModel]

    init(
        company: Company, vehicles: [Vehicle], drivers: [Driver], telemetry: [TelemetrySnapshot],
        dailyMetrics: [DailyMetric], trips: [Trip], maintenance: [MaintenanceRecord], expenses: [Expense],
        valuationModels: [ValuationModel], alerts: [FleetAlert], geofences: [Geofence]
    ) {
        self.company = company
        self.vehicles = vehicles.sorted { $0.plate < $1.plate }
        self.drivers = drivers
        self.telemetry = telemetry
        self.dailyMetrics = dailyMetrics
        self.trips = trips.sorted { $0.startTime > $1.startTime }
        self.maintenance = maintenance.sorted { $0.date > $1.date }
        self.expenses = expenses
        self.valuationModels = valuationModels
        self.alerts = alerts.sorted { $0.timestamp > $1.timestamp }
        self.geofences = geofences

        metricsByVehicle = Dictionary(grouping: dailyMetrics, by: \.vehicleId)
        maintenanceByVehicle = Dictionary(grouping: self.maintenance, by: \.vehicleId)
        expensesByVehicle = Dictionary(grouping: expenses, by: \.vehicleId)
        tripsByVehicle = Dictionary(grouping: self.trips, by: \.vehicleId)
        telemetryByVehicle = Dictionary(telemetry.map { ($0.vehicleId, $0) }, uniquingKeysWith: { $1 })
        driversById = Dictionary(drivers.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        modelsBySegment = Dictionary(valuationModels.map { ($0.segment, $0) }, uniquingKeysWith: { $1 })
    }

    func metrics(for vehicleId: String) -> [DailyMetric] { metricsByVehicle[vehicleId] ?? [] }
    func maintenance(for vehicleId: String) -> [MaintenanceRecord] { maintenanceByVehicle[vehicleId] ?? [] }
    func expenses(for vehicleId: String) -> [Expense] { expensesByVehicle[vehicleId] ?? [] }
    func trips(for vehicleId: String) -> [Trip] { tripsByVehicle[vehicleId] ?? [] }
    func telemetry(for vehicleId: String) -> TelemetrySnapshot? { telemetryByVehicle[vehicleId] }
    func driver(id: String?) -> Driver? { id.flatMap { driversById[$0] } }
    func valuationModel(for segment: VehicleSegment) -> ValuationModel? { modelsBySegment[segment] }
    func vehicle(id: String) -> Vehicle? { vehicles.first { $0.id == id } }
    func alerts(for vehicleId: String) -> [FleetAlert] { alerts.filter { $0.vehicleId == vehicleId } }
}
