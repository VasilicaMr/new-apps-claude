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
            result.append(Insight(kind: .start, text: String(localized: "No shifts logged this week yet. Start a shift when you go online, then add your trip screenshots for the kilometers.")))
        } else {
            let net = money.string(week.net), earned = money.string(week.earnings)
            let summary = switch (week.hours > 0 ? Formatters.hours(week.hours) : nil, week.netPerHour.map { money.string($0) }) {
            case let (hours?, perHour?):
                String(localized: "This week: \(net) net from \(earned) earned over \(hours) (\(perHour) net per hour).")
            case let (hours?, nil):
                String(localized: "This week: \(net) net from \(earned) earned over \(hours).")
            default:
                String(localized: "This week: \(net) net from \(earned) earned.")
            }
            result.append(Insight(kind: .summary, text: summary))
        }

        if let now = input.thisWeek.netPerHour, let before = input.lastWeek.netPerHour, before > 0, input.thisWeek.hours >= 4 {
            let change = (now - before) / before
            if abs(change) >= 0.05 {
                let percent = abs(change).percentString, from = money.string(before), to = money.string(now)
                result.append(Insight(kind: .trend, text: change > 0
                    ? String(localized: "Net per hour is up \(percent) compared with last week (\(from) → \(to)).")
                    : String(localized: "Net per hour is down \(percent) compared with last week (\(from) → \(to)).")))
            }
        }

        if let best = bestWeekday(input.recentDays) {
            result.append(Insight(kind: .bestDay, text: String(localized: "Your best day is usually \(best.name): about \(money.string(best.perHour)) per hour before costs.")))
        }

        if let top = input.thisMonth.expensesByCategory.max(by: { $0.value < $1.value }), input.thisMonth.expenses > 0 {
            let category = top.key.title.lowercased(), amount = money.string(top.value)
            let share = (top.value / input.thisMonth.expenses).percentString
            let text = if let perKm = input.thisMonth.costPerKm.map({ money.string($0, decimals: true) }) {
                String(localized: "Biggest cost this month: \(category), \(amount) (\(share) of costs); all costs come to \(perKm) per km.")
            } else {
                String(localized: "Biggest cost this month: \(category), \(amount) (\(share) of costs).")
            }
            result.append(Insight(kind: .cost, text: text))
        }

        if input.shiftsWithoutEarnings > 0 {
            let count = input.shiftsWithoutEarnings
            result.append(Insight(kind: .missingEarnings, text: String(localized: "\(count) recent shifts have no earnings yet. Add a screenshot so your per-hour numbers are right.")))
        }

        for (title, status) in input.dueReminders.sorted(by: { $0.status.urgency > $1.status.urgency }).prefix(2) {
            let text: String
            if let days = status.daysLeft {
                text = days < 0 ? String(localized: "\(title) expired \(abs(days)) days ago.")
                    : days == 0 ? String(localized: "\(title) is due today.")
                    : String(localized: "\(title) is due in \(days) days.")
            } else if let km = status.kmLeft {
                text = km <= 0 ? String(localized: "\(title) is overdue.") : String(localized: "\(title) is due in \(km.kilometers).")
            } else {
                continue
            }
            result.append(Insight(kind: .reminder, text: text))
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
