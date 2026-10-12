import Foundation

/// Estimates market value from age and mileage with a classic declining-balance curve,
/// corrected for how far the odometer is from the segment's "normal" mileage.
///
/// This is a heuristic. For real numbers plug in a valuation API (e.g. Autovit/Mobile.de
/// listings, Eurotax/Schwacke, or Black Book) behind `ValuationModel`.
struct ValuationCalculator: Sendable {
    private let secondsPerYear = 365.25 * 86_400
    private let curveSteps = 24
    private let projectionYears = 2.0

    func valuation(for vehicle: Vehicle, model: ValuationModel, odometerKm: Double? = nil, asOf: Date) -> VehicleValuation {
        let odometer = odometerKm ?? vehicle.odometerKm
        let age = ageYears(of: vehicle, at: asOf)
        let kmPerYear = odometer / max(age, 0.25)

        let current = value(purchasePrice: vehicle.purchasePrice, ageYears: age, odometerKm: odometer, model: model)
        let maxKm = odometer + kmPerYear * projectionYears
        let curve = (0...curveSteps).map { step -> VehicleValuation.CurvePoint in
            let km = maxKm * Double(step) / Double(curveSteps)
            let projectedAge = km / max(kmPerYear, 1)
            let projected = value(purchasePrice: vehicle.purchasePrice, ageYears: projectedAge, odometerKm: km, model: model)
            return .init(odometerKm: km, value: projected)
        }

        return VehicleValuation(
            purchasePrice: vehicle.purchasePrice,
            currentValue: current,
            ageYears: age,
            mileageFactor: mileageFactor(ageYears: age, odometerKm: odometer, model: model),
            curve: curve
        )
    }

    func value(purchasePrice: Double, ageYears: Double, odometerKm: Double, model: ValuationModel) -> Double {
        let age = max(0, ageYears)
        let ageValue: Double = if age <= 1 {
            purchasePrice * (1 - model.firstYearRate * age)
        } else {
            purchasePrice * (1 - model.firstYearRate) * pow(1 - model.annualRate, age - 1)
        }
        let adjusted = ageValue * mileageFactor(ageYears: age, odometerKm: odometerKm, model: model)
        return max(purchasePrice * model.residualFloorRate, adjusted)
    }

    func ageYears(of vehicle: Vehicle, at date: Date) -> Double {
        max(0, date.timeIntervalSince(vehicle.purchaseDate) / secondsPerYear)
    }

    /// > 1 for low-mileage cars, < 1 for high-mileage ones. Clamped so extreme odometers
    /// don't produce absurd values.
    private func mileageFactor(ageYears: Double, odometerKm: Double, model: ValuationModel) -> Double {
        let expectedKm = model.expectedAnnualKm * ageYears
        let excessTenThousands = (odometerKm - expectedKm) / 10_000
        return min(1.15, max(0.6, 1 - excessTenThousands * model.mileageAdjustmentPer10kKm))
    }
}
