import Foundation

// Plain value inputs so the math is testable without SwiftData.

struct ShiftFigures: Sendable, Hashable {
    let start: Date
    let end: Date
    let distanceKm: Double
    let movingHours: Double

    var hours: Double { max(0, end.timeIntervalSince(start)) / 3600 }
}

struct EarningFigures: Sendable, Hashable {
    let date: Date
    let platform: Platform
    let fares: Double
    let tips: Double
    let bonus: Double
    let trips: Int

    var total: Double { fares + tips + bonus }
}

struct ExpenseFigures: Sendable, Hashable {
    let date: Date
    let category: ExpenseCategory
    let amount: Double
    /// 0 = one-off cost on `date`; otherwise spread evenly over this many months from `date`.
    let coverageMonths: Int
}

struct DayStats: Sendable, Hashable, Identifiable {
    let day: Date
    let earnings: Double
    let expenses: Double
    let km: Double
    let hours: Double

    var id: Date { day }
    var net: Double { earnings - expenses }
}

struct PeriodStats: Sendable, Hashable {
    let interval: DateInterval
    let earnings: Double
    let tips: Double
    let trips: Int
    let earningsByPlatform: [Platform: Double]
    let expenses: Double
    let expensesByCategory: [ExpenseCategory: Double]
    let km: Double
    let hours: Double
    let movingHours: Double
    let shiftCount: Int
    let days: [DayStats]

    var net: Double { earnings - expenses }
    var earningsPerHour: Double? { hours > 0 ? earnings / hours : nil }
    var netPerHour: Double? { hours > 0 ? net / hours : nil }
    var netPerKm: Double? { km > 0 ? net / km : nil }
    var costPerKm: Double? { km > 0 ? expenses / km : nil }
    /// Share of shift time spent actually driving (the rest is waiting or in traffic jams).
    var movingShare: Double? { hours > 0 ? min(1, movingHours / hours) : nil }
}

enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    func interval(offset: Int, from date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let shifted = calendar.date(byAdding: component, value: offset, to: date) ?? date
        return interval(containing: shifted, calendar: calendar)
    }
}

/// Totals and per-day series for a time range.
///
/// Rules (kept simple so drivers can check them by hand):
/// - A shift, its kilometers and hours belong to the day it **started** (a Friday night shift
///   that ends at 3 AM is still Friday). Earnings are dated by the driver, defaulting to the shift start.
/// - Expenses with `coverageMonths > 0` are spread evenly per day over the period they cover.
struct StatsCalculator: Sendable {
    var calendar: Calendar = .current

    func stats(in interval: DateInterval, shifts: [ShiftFigures], earnings: [EarningFigures],
               expenses: [ExpenseFigures]) -> PeriodStats {
        let shiftsIn = shifts.filter { contains(interval, $0.start) }
        let earningsIn = earnings.filter { contains(interval, $0.date) }

        var byPlatform: [Platform: Double] = [:]
        for earning in earningsIn { byPlatform[earning.platform, default: 0] += earning.total }

        var byCategory: [ExpenseCategory: Double] = [:]
        for expense in expenses {
            let share = amount(of: expense, in: interval)
            if share > 0 { byCategory[expense.category, default: 0] += share }
        }

        return PeriodStats(
            interval: interval,
            earnings: earningsIn.reduce(0) { $0 + $1.total },
            tips: earningsIn.reduce(0) { $0 + $1.tips },
            trips: earningsIn.reduce(0) { $0 + $1.trips },
            earningsByPlatform: byPlatform,
            expenses: byCategory.values.reduce(0, +),
            expensesByCategory: byCategory,
            km: shiftsIn.reduce(0) { $0 + $1.distanceKm },
            hours: shiftsIn.reduce(0) { $0 + $1.hours },
            movingHours: shiftsIn.reduce(0) { $0 + $1.movingHours },
            shiftCount: shiftsIn.count,
            days: days(in: interval, shifts: shiftsIn, earnings: earningsIn, expenses: expenses))
    }

    /// The part of an expense that falls inside `interval`.
    func amount(of expense: ExpenseFigures, in interval: DateInterval) -> Double {
        guard expense.coverageMonths > 0 else {
            return contains(interval, expense.date) ? expense.amount : 0
        }
        let start = calendar.startOfDay(for: expense.date)
        guard let end = calendar.date(byAdding: .month, value: expense.coverageMonths, to: start) else { return 0 }
        let covered = DateInterval(start: start, end: end)
        guard let overlap = covered.intersection(with: interval), overlap.duration > 0 else { return 0 }
        return expense.amount * overlap.duration / covered.duration
    }

    private func days(in interval: DateInterval, shifts: [ShiftFigures], earnings: [EarningFigures],
                      expenses: [ExpenseFigures]) -> [DayStats] {
        var result: [DayStats] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let dayInterval = DateInterval(start: day, end: next)
            let dayShifts = shifts.filter { contains(dayInterval, $0.start) }
            result.append(DayStats(
                day: day,
                earnings: earnings.filter { contains(dayInterval, $0.date) }.reduce(0) { $0 + $1.total },
                expenses: expenses.reduce(0) { $0 + amount(of: $1, in: dayInterval) },
                km: dayShifts.reduce(0) { $0 + $1.distanceKm },
                hours: dayShifts.reduce(0) { $0 + $1.hours }))
            day = next
        }
        return result
    }

    /// Half-open: a timestamp exactly at midnight belongs to the new day.
    private func contains(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }
}
