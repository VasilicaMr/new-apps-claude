import Foundation
import Testing
@testable import FleetCheck

@Suite("Valuation")
struct ValuationCalculatorTests {
    let calculator = ValuationCalculator()
    let model = TestData.sedanModel

    @Test func newCarKeepsPurchasePrice() {
        #expect(calculator.value(purchasePrice: 20_000, ageYears: 0, odometerKm: 0, model: model) == 20_000)
    }

    @Test func firstYearLoss() {
        // Average mileage → mileage factor 1, so only age counts: 20,000 × (1 − 0.20).
        let value = calculator.value(purchasePrice: 20_000, ageYears: 1, odometerKm: 30_000, model: model)
        #expect(abs(value - 16_000) < 0.01)
    }

    @Test func highMileageIsWorthLess() {
        let average = calculator.value(purchasePrice: 20_000, ageYears: 3, odometerKm: 90_000, model: model)
        let high = calculator.value(purchasePrice: 20_000, ageYears: 3, odometerKm: 190_000, model: model)
        let low = calculator.value(purchasePrice: 20_000, ageYears: 3, odometerKm: 40_000, model: model)
        #expect(high < average)
        #expect(low > average)
        // 100k km over expectation × 2% per 10k = −20%.
        #expect(abs(high / average - 0.8) < 0.001)
    }

    @Test func neverDropsBelowResidualFloor() {
        let value = calculator.value(purchasePrice: 20_000, ageYears: 25, odometerKm: 900_000, model: model)
        #expect(value == 20_000 * model.residualFloorRate)
    }

    @Test func curveIsDecreasingAndCoversToday() {
        let vehicle = TestData.vehicle()
        let valuation = calculator.valuation(for: vehicle, model: model, asOf: TestData.date("2025-10-11"))
        let values = valuation.curve.map(\.value)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(valuation.curve.last!.odometerKm > vehicle.odometerKm)
    }
}
