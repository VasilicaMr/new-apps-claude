import Foundation

struct UsageStats: Sendable, Hashable {
    var distanceKm: Double = 0
    var activeDays = 0
    var totalDays = 0
    var drivingMinutes: Double = 0
    var idleMinutes: Double = 0
    var energyUsed: Double = 0
    var jobs = 0
    var harshEvents = 0

    /// Share of days the vehicle actually worked.
    var utilization: Double { totalDays > 0 ? Double(activeDays) / Double(totalDays) : 0 }
    var idleShare: Double { drivingMinutes + idleMinutes > 0 ? idleMinutes / (drivingMinutes + idleMinutes) : 0 }
    var consumptionPer100Km: Double { distanceKm > 0 ? energyUsed / distanceKm * 100 : 0 }
    var harshEventsPer100Km: Double { distanceKm > 0 ? Double(harshEvents) / distanceKm * 100 : 0 }
    /// 100 = no harsh events; every event per 100 km costs 12 points.
    var drivingScore: Double { max(0, min(100, 100 - harshEventsPer100Km * 12)) }
}

struct VehicleReport: Sendable, Identifiable, Hashable {
    let vehicle: Vehicle
    let driver: Driver?
    let financials: Financials
    let monthly: [MonthlyFinancials]
    let usage: UsageStats
    let valuation: VehicleValuation?
    let dueItems: [DueItem]
    /// Maintenance spend over the trailing 12 months, regardless of the selected period.
    let maintenanceLast12Months: Double

    var id: String { vehicle.id }
    var profitPerKm: Double { usage.distanceKm > 0 ? financials.profit / usage.distanceKm : 0 }
    var costPerKm: Double { usage.distanceKm > 0 ? financials.totalCost / usage.distanceKm : 0 }
    /// Positive when the vehicle burns more than its baseline (e.g. 0.18 = 18% more).
    var consumptionDeviation: Double {
        guard vehicle.baselineConsumption > 0, usage.consumptionPer100Km > 0 else { return 0 }
        return usage.consumptionPer100Km / vehicle.baselineConsumption - 1
    }
    var repairBurden: Double {
        guard let value = valuation?.currentValue, value > 0 else { return 0 }
        return maintenanceLast12Months / value
    }
}

struct FleetReport: Sendable {
    let period: AnalysisPeriod
    let range: DateRange
    let vehicles: [VehicleReport]
    let monthly: [MonthlyFinancials]

    var financials: Financials { vehicles.reduce(Financials()) { $0 + $1.financials } }
    var fleetValue: Double { vehicles.reduce(0) { $0 + ($1.valuation?.currentValue ?? 0) } }
    var purchaseValue: Double { vehicles.reduce(0) { $0 + $1.vehicle.purchasePrice } }
    var distanceKm: Double { vehicles.reduce(0) { $0 + $1.usage.distanceKm } }
    var dueItems: [DueItem] { vehicles.flatMap(\.dueItems).sorted { $0.dueDate < $1.dueDate } }
    var averageUtilization: Double {
        vehicles.isEmpty ? 0 : vehicles.reduce(0) { $0 + $1.usage.utilization } / Double(vehicles.count)
    }

    /// Costs grouped for a breakdown chart, largest first.
    var costBreakdown: [(label: String, amount: Double)] {
        let totals = financials
        var rows: [(String, Double)] = [
            ("Fuel & energy", totals.energyCost),
            ("Maintenance", totals.maintenanceCost),
            ("Depreciation", totals.depreciation),
        ]
        rows += totals.expenses.map { ($0.key.label, $0.value) }
        return rows.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }
}

/// Composition root of the analysis: builds one report per vehicle plus fleet totals.
struct FleetAnalyzer: Sendable {
    var finance = FinancialAnalyzer()
    var planner = MaintenancePlanner()

    func report(for snapshot: FleetSnapshot, period: AnalysisPeriod) -> FleetReport {
        let range = DateRange.lastDays(period.rawValue, endingOn: snapshot.company.dataAsOf)
        let yearRange = DateRange.lastDays(365, endingOn: snapshot.company.dataAsOf)
        let reports = snapshot.vehicles.map { vehicle in
            VehicleReport(
                vehicle: vehicle,
                driver: snapshot.driver(id: vehicle.assignedDriverId),
                financials: finance.financials(for: vehicle, in: range, snapshot: snapshot),
                monthly: finance.monthly(for: vehicle, in: range, snapshot: snapshot),
                usage: usage(for: vehicle, in: range, snapshot: snapshot),
                valuation: snapshot.valuationModel(for: vehicle.segment).map {
                    finance.valuation.valuation(for: vehicle, model: $0, asOf: snapshot.company.dataAsOf)
                },
                dueItems: planner.dueItems(for: vehicle, snapshot: snapshot),
                maintenanceLast12Months: snapshot.maintenance(for: vehicle.id)
                    .filter { yearRange.contains($0.date) }
                    .reduce(0) { $0 + $1.totalCost }
            )
        }
        return FleetReport(period: period, range: range, vehicles: reports, monthly: combineMonthly(reports))
    }

    func usage(for vehicle: Vehicle, in range: DateRange, snapshot: FleetSnapshot) -> UsageStats {
        let metrics = snapshot.metrics(for: vehicle.id).filter { range.contains($0.date) }
        var stats = UsageStats()
        stats.totalDays = metrics.count
        for day in metrics {
            stats.distanceKm += day.distanceKm
            stats.activeDays += day.isActive ? 1 : 0
            stats.drivingMinutes += day.drivingMinutes
            stats.idleMinutes += day.idleMinutes
            stats.energyUsed += day.energyUsed
            stats.jobs += day.jobsCompleted
            stats.harshEvents += day.harshEvents
        }
        return stats
    }

    private func combineMonthly(_ reports: [VehicleReport]) -> [MonthlyFinancials] {
        var byMonth: [Date: Financials] = [:]
        for row in reports.flatMap(\.monthly) {
            byMonth[row.month, default: Financials()] = byMonth[row.month, default: Financials()] + row.financials
        }
        return byMonth.map { MonthlyFinancials(month: $0.key, financials: $0.value) }.sorted { $0.month < $1.month }
    }
}

extension ExpenseCategory {
    var label: String {
        switch self {
        case .driverWages: "Driver wages"
        case .insurance: "Insurance"
        case .roadTax: "Road tax"
        case .financing: "Leasing"
        case .parking: "Parking"
        case .cleaning: "Cleaning"
        case .tolls: "Tolls"
        case .fines: "Fines"
        }
    }
}
