import Foundation

enum MaintenanceCategory: String, Codable, Sendable, CaseIterable {
    case service, tires, brakes, engine, transmission, electrical, bodywork, suspension, inspection

    var symbol: String {
        switch self {
        case .service: "wrench.and.screwdriver"
        case .tires: "circle.circle"
        case .brakes: "exclamationmark.brakesignal"
        case .engine: "engine.combustion"
        case .transmission: "gearshape.2"
        case .electrical: "bolt.car"
        case .bodywork: "car.side.rear.and.collision.and.car.side.front"
        case .suspension: "car.side.lock"
        case .inspection: "checkmark.seal"
        }
    }
}

struct MaintenanceRecord: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let vehicleId: String
    let date: Date
    let odometerKm: Double
    let category: MaintenanceCategory
    let description: String
    let partsCost: Double
    let laborCost: Double
    let garage: String
    let downtimeDays: Int
    /// Breakdowns and accidents, as opposed to scheduled work.
    let isUnplanned: Bool

    var totalCost: Double { partsCost + laborCost }
}

enum ExpenseCategory: String, Codable, Sendable, CaseIterable {
    case driverWages, insurance, roadTax, financing, parking, cleaning, tolls, fines
}

struct Expense: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let vehicleId: String
    let date: Date
    let category: ExpenseCategory
    let amount: Double
    let note: String
}
