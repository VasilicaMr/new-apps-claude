import Foundation

struct Financials: Sendable, Hashable {
    var revenue: Double = 0
    var energyCost: Double = 0
    var maintenanceCost: Double = 0
    var expenses: [ExpenseCategory: Double] = [:]
    /// Loss of market value during the period. Not a cash cost, but a real one.
    var depreciation: Double = 0

    var otherExpenses: Double { expenses.values.reduce(0, +) }
    var cashCost: Double { energyCost + maintenanceCost + otherExpenses }
    var totalCost: Double { cashCost + depreciation }
    var profit: Double { revenue - totalCost }
    var margin: Double { revenue > 0 ? profit / revenue : 0 }

    static func + (lhs: Financials, rhs: Financials) -> Financials {
        Financials(
            revenue: lhs.revenue + rhs.revenue,
            energyCost: lhs.energyCost + rhs.energyCost,
            maintenanceCost: lhs.maintenanceCost + rhs.maintenanceCost,
            expenses: lhs.expenses.merging(rhs.expenses, uniquingKeysWith: +),
            depreciation: lhs.depreciation + rhs.depreciation
        )
    }
}

struct MonthlyFinancials: Sendable, Hashable, Identifiable {
    let month: Date
    let financials: Financials
    var id: Date { month }
}

/// Turns raw feeds into money: revenue, cash costs and depreciation for any date range.
struct FinancialAnalyzer: Sendable {
    let valuation = ValuationCalculator()

    func financials(for vehicle: Vehicle, in range: DateRange, snapshot: FleetSnapshot) -> Financials {
        let metrics = snapshot.metrics(for: vehicle.id).filter { range.contains($0.date) }
        var result = Financials()
        result.revenue = metrics.reduce(0) { $0 + $1.revenue }
        result.energyCost = metrics.reduce(0) { $0 + $1.energyCost }
        result.maintenanceCost = snapshot.maintenance(for: vehicle.id)
            .filter { range.contains($0.date) }
            .reduce(0) { $0 + $1.totalCost }
        for expense in snapshot.expenses(for: vehicle.id) {
            let amount = amortizedAmount(of: expense, in: range)
            if amount > 0 { result.expenses[expense.category, default: 0] += amount }
        }
        result.depreciation = depreciation(of: vehicle, in: range, distanceKm: metrics.reduce(0) { $0 + $1.distanceKm }, snapshot: snapshot)
        return result
    }

    func monthly(for vehicle: Vehicle, in range: DateRange, snapshot: FleetSnapshot) -> [MonthlyFinancials] {
        monthRanges(covering: range).map { month in
            MonthlyFinancials(month: month.start, financials: financials(for: vehicle, in: month, snapshot: snapshot))
        }
    }

    /// Recurring payments (insurance, road tax, salaries, leasing) are spread over the days they
    /// cover, otherwise a short report would show a huge loss whenever a payment lands in it.
    func amortizedAmount(of expense: Expense, in range: DateRange) -> Double {
        guard let coverageDays = expense.category.coverageDays else {
            return range.contains(expense.date) ? expense.amount : 0
        }
        let coverage = coverageDays * 86_400
        let overlapStart = max(range.start, expense.date)
        let overlapEnd = min(range.end, expense.date.addingTimeInterval(coverage))
        guard overlapEnd > overlapStart else { return 0 }
        return expense.amount * overlapEnd.timeIntervalSince(overlapStart) / coverage
    }

    private func depreciation(of vehicle: Vehicle, in range: DateRange, distanceKm: Double, snapshot: FleetSnapshot) -> Double {
        guard let model = snapshot.valuationModel(for: vehicle.segment) else { return 0 }
        let asOfEnd = min(range.end, snapshot.company.dataAsOf.addingTimeInterval(86_400))
        let kmDrivenAfterRange = snapshot.metrics(for: vehicle.id)
            .filter { $0.date >= range.end }
            .reduce(0) { $0 + $1.distanceKm }
        let odometerAtEnd = vehicle.odometerKm - kmDrivenAfterRange
        let endValue = valuation.value(
            purchasePrice: vehicle.purchasePrice,
            ageYears: valuation.ageYears(of: vehicle, at: asOfEnd),
            odometerKm: odometerAtEnd, model: model)
        let startValue = valuation.value(
            purchasePrice: vehicle.purchasePrice,
            ageYears: valuation.ageYears(of: vehicle, at: range.start),
            odometerKm: max(0, odometerAtEnd - distanceKm), model: model)
        return max(0, startValue - endValue)
    }

    private func monthRanges(covering range: DateRange, calendar: Calendar = .fleet) -> [DateRange] {
        var months: [DateRange] = []
        var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: range.start))!
        while cursor < range.end {
            let next = calendar.date(byAdding: .month, value: 1, to: cursor)!
            months.append(DateRange(start: max(cursor, range.start), end: min(next, range.end)))
            cursor = next
        }
        return months
    }
}

extension ExpenseCategory {
    /// Days a single payment pays for; nil for one-off costs booked on their date.
    var coverageDays: Double? {
        switch self {
        case .insurance, .roadTax: 365
        case .driverWages, .financing: 30
        case .parking, .cleaning, .tolls, .fines: nil
        }
    }
}
