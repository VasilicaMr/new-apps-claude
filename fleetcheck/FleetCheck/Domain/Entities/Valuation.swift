import Foundation

/// Depreciation parameters per vehicle segment, served by the backend so they can be tuned
/// to the local used-car market without an app update.
struct ValuationModel: Codable, Sendable, Hashable {
    let segment: VehicleSegment
    /// Share of the purchase price lost during the first year.
    let firstYearRate: Double
    /// Share of the remaining value lost every following year.
    let annualRate: Double
    /// Mileage the market considers "normal" per year for this segment.
    let expectedAnnualKm: Double
    /// Value adjustment per 10,000 km above (−) or below (+) the expected mileage.
    let mileageAdjustmentPer10kKm: Double
    /// The value never drops below this share of the purchase price (scrap / export value).
    let residualFloorRate: Double
}

struct VehicleValuation: Sendable, Hashable {
    struct CurvePoint: Sendable, Hashable, Identifiable {
        let odometerKm: Double
        let value: Double
        var id: Double { odometerKm }
    }

    let purchasePrice: Double
    let currentValue: Double
    let ageYears: Double
    /// Multiplier applied for above/below-average mileage (1.0 = average).
    let mileageFactor: Double
    /// Projected value against odometer, assuming the vehicle keeps its current km/year pace.
    let curve: [CurvePoint]

    var totalDepreciation: Double { purchasePrice - currentValue }
    var retainedShare: Double { purchasePrice > 0 ? currentValue / purchasePrice : 0 }
}
