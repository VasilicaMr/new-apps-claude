import Foundation
@testable import FleetCheck

enum TestData {
    static let calendar = Calendar.fleet

    static func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)!
    }

    static func loadSnapshot() async throws -> FleetSnapshot {
        try await DefaultFleetRepository(client: MockAPIClient(latency: .zero)).loadSnapshot()
    }

    static let sedanModel = ValuationModel(
        segment: .sedan, firstYearRate: 0.20, annualRate: 0.12, expectedAnnualKm: 30_000,
        mileageAdjustmentPer10kKm: 0.02, residualFloorRate: 0.12)

    static func vehicle(price: Double = 20_000, purchased: String = "2022-10-11", odometer: Double = 60_000) -> Vehicle {
        Vehicle(
            id: "veh-test", plate: "T-001", vin: "VIN", make: "Test", model: "Car", year: 2022,
            fuelType: .petrol, segment: .sedan, color: "White", purchaseDate: date(purchased), purchasePrice: price,
            odometerKm: odometer, baselineConsumption: 6, tankCapacity: 50, serviceIntervalKm: 15_000,
            nextServiceKm: 75_000, insuranceExpiry: date("2027-01-01"), inspectionExpiry: date("2027-01-01"),
            roadTaxExpiry: date("2027-01-01"), assignedDriverId: nil, operationalStatus: .active, monthlyFinancingCost: 0)
    }
}
