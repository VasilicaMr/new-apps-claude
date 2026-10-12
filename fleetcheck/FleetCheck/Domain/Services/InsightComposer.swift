import Foundation

/// Facts worth telling the driver, computed (never guessed) from their data.
/// Apple Intelligence turns these into a friendly brief; without it they are shown as they are.
struct Insight: Sendable, Equatable, Identifiable {
    enum Kind: String, Sendable { case summary, trend, bestDay, cost, missingEarnings, reminder, start }

    let kind: Kind
    let text: String
    var id: String { kind.rawValue + text }
}

struct InsightComposer: Sendable {
    var calendar: Calendar = .current
    var money: MoneyFormatter

    struct Input: Sendable {
        let thisWeek: PeriodStats
        let lastWeek: PeriodStats
        /// Daily figures for the last ~8 weeks, used to find the best weekday.
        let recentDays: [DayStats]
        let thisMonth: PeriodStats
        let shiftsWithoutEarnings: Int
        let dueReminders: [(title: String, status: ReminderStatus)]
    }

    func insights(_ input: Input) -> [Insight] {
        var result: [Insight] = []
        let week = input.thisWeek

        if week.shiftCount == 0 && week.earnings == 0 {
            result.append(Insight(kind: .start, text: "No shifts logged this week yet. Start a shift when you go online and FleetCheck counts the kilometers for you."))
        } else {
            var summary = "This week: \(money.string(week.net)) net from \(money.string(week.earnings)) earned"
            if week.hours > 0 { summary += " over \(Formatters.hours(week.hours))" }
            if let perHour = week.netPerHour { summary += " (\(money.string(perHour)) net per hour)" }
            result.append(Insight(kind: .summary, text: summary + "."))
        }

        if let now = input.thisWeek.netPerHour, let before = input.lastWeek.netPerHour, before > 0, input.thisWeek.hours >= 4 {
            let change = (now - before) / before
            if abs(change) >= 0.05 {
                result.append(Insight(kind: .trend, text: "Net per hour is \(change > 0 ? "up" : "down") \(abs(change).percentString) compared with last week (\(money.string(before)) → \(money.string(now)))."))
            }
        }

        if let best = bestWeekday(input.recentDays) {
            result.append(Insight(kind: .bestDay, text: "Your best day is usually \(best.name): about \(money.string(best.perHour)) per hour before costs."))
        }

        if let top = input.thisMonth.expensesByCategory.max(by: { $0.value < $1.value }), input.thisMonth.expenses > 0 {
            var text = "Biggest cost this month: \(top.key.title.lowercased()), \(money.string(top.value)) (\((top.value / input.thisMonth.expenses).percentString) of costs)"
            if let perKm = input.thisMonth.costPerKm { text += "; all costs come to \(money.string(perKm, decimals: true)) per km" }
            result.append(Insight(kind: .cost, text: text + "."))
        }

        if input.shiftsWithoutEarnings > 0 {
            let count = input.shiftsWithoutEarnings
            result.append(Insight(kind: .missingEarnings, text: "\(count) recent shift\(count == 1 ? " has" : "s have") no earnings yet. Add a screenshot so your per-hour numbers are right."))
        }

        for (title, status) in input.dueReminders.sorted(by: { $0.status.urgency > $1.status.urgency }).prefix(2) {
            let when: String
            if let days = status.daysLeft {
                when = days < 0 ? "expired \(abs(days)) day\(abs(days) == 1 ? "" : "s") ago" : days == 0 ? "is due today" : "is due in \(days) day\(days == 1 ? "" : "s")"
            } else if let km = status.kmLeft {
                when = km <= 0 ? "is overdue" : "is due in \(km.kilometers)"
            } else {
                continue
            }
            result.append(Insight(kind: .reminder, text: "\(title) \(when)."))
        }
        return result
    }

    /// Weekday with the highest earnings per hour, from days with at least one hour of driving;
    /// needs the weekday to appear at least twice so one lucky day doesn't decide it.
    func bestWeekday(_ days: [DayStats]) -> (name: String, perHour: Double)? {
        let worked = days.filter { $0.hours >= 1 }
        let byWeekday = Dictionary(grouping: worked) { calendar.component(.weekday, from: $0.day) }
        var candidates: [(weekday: Int, perHour: Double)] = []
        for (weekday, days) in byWeekday where days.count >= 2 {
            let earnings = days.reduce(0.0) { $0 + $1.earnings }
            let hours = days.reduce(0.0) { $0 + $1.hours }
            candidates.append((weekday, earnings / hours))
        }
        guard candidates.count >= 3, let best = candidates.max(by: { $0.perHour < $1.perHour }) else { return nil }
        return (calendar.weekdaySymbols[best.weekday - 1], best.perHour)
    }
}
