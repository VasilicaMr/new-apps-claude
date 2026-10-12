import Foundation

enum FuelType: String, Codable, Sendable, CaseIterable {
    case petrol, diesel, hybrid, electric

    /// Unit used for consumption and energy figures.
    var energyUnit: String { self == .electric ? "kWh" : "L" }
}

enum VehicleSegment: String, Codable, Sendable, CaseIterable {
    case economy, sedan, suv, van
}

enum OperationalStatus: String, Codable, Sendable {
    case active, inMaintenance, retired
}

struct Vehicle: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let plate: String
    let vin: String
    let make: String
    let model: String
    let year: Int
    let fuelType: FuelType
    let segment: VehicleSegment
    let color: String
    let purchaseDate: Date
    let purchasePrice: Double
    let odometerKm: Double
    /// Manufacturer/real-world consumption per 100 km (L or kWh).
    let baselineConsumption: Double
    let tankCapacity: Double
    let serviceIntervalKm: Double
    let nextServiceKm: Double
    let insuranceExpiry: Date
    let inspectionExpiry: Date
    let roadTaxExpiry: Date
    let assignedDriverId: String?
    let operationalStatus: OperationalStatus
    let monthlyFinancingCost: Double

    var displayName: String { "\(make) \(model)" }
}
