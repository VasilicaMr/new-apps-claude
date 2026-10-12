import Foundation

/// Half-open day range `[start, end)` used for every analytics window.
struct DateRange: Sendable, Hashable {
    let start: Date
    let end: Date

    /// The `days` full days ending on (and including) `asOf`.
    static func lastDays(_ days: Int, endingOn asOf: Date, calendar: Calendar = .fleet) -> DateRange {
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: asOf))!
        let start = calendar.date(byAdding: .day, value: -days, to: endExclusive)!
        return DateRange(start: start, end: endExclusive)
    }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    var days: Double { end.timeIntervalSince(start) / 86_400 }
}

extension Calendar {
    /// All feed dates are calendar days in UTC ("2026-10-11"), so analytics use a UTC calendar
    /// to avoid off-by-one-day bugs around midnight in the user's timezone.
    static let fleet: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

enum AnalysisPeriod: Int, CaseIterable, Identifiable, Sendable {
    case week = 7, month = 30, quarter = 90, halfYear = 180

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .week: "7D"
        case .month: "30D"
        case .quarter: "90D"
        case .halfYear: "180D"
        }
    }
}
