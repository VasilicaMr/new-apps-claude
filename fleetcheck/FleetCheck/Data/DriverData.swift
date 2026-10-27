import Foundation
import SwiftData

/// One place to read and write the driver's data, shared by the Home screen, the assistant,
/// its Apple Intelligence tools and Siri. All numbers come from here, never from the language model.
@MainActor
final class DriverData {
    let context: ModelContext
    var calculator = StatsCalculator()
    private let planner = ReminderPlanner()

    init(context: ModelContext) {
        self.context = context
    }

    var money: MoneyFormatter {
        MoneyFormatter(currencyCode: UserDefaults.standard.string(forKey: SettingsKeys.currencyCode) ?? MoneyFormatter.defaultCurrencyCode)
    }

    // MARK: - Reading

    func shifts() -> [Shift] { (try? context.fetch(FetchDescriptor<Shift>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? [] }
    func earnings() -> [Earning] { (try? context.fetch(FetchDescriptor<Earning>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? [] }
    func expenses() -> [Expense] { (try? context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? [] }
    func reminders() -> [Reminder] { (try? context.fetch(FetchDescriptor<Reminder>())) ?? [] }
    var car: Car { context.car() }

    func stats(_ period: StatsPeriod, offset: Int = 0) -> PeriodStats {
        stats(in: elapsed(period.interval(offset: offset)))
    }

    func stats(in interval: DateInterval) -> PeriodStats {
        calculator.stats(in: interval,
                         shifts: shifts().filter { !$0.isActive }.map(\.figures),
                         earnings: earnings().map(\.figures),
                         expenses: expenses().map(\.figures))
    }

    /// Stops at the end of today so costs spread over months aren't charged for days still to come.
    private func elapsed(_ interval: DateInterval) -> DateInterval {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return DateInterval(start: interval.start, end: max(interval.start, min(interval.end, endOfToday)))
    }

    func reminderStatuses() -> [(reminder: Reminder, status: ReminderStatus)] {
        let odometer = car.odometerKm
        return reminders()
            .map { ($0, planner.status(of: $0.rule, today: .now, odometerKm: odometer)) }
            .sorted { lhs, rhs in
                lhs.1.urgency != rhs.1.urgency ? lhs.1.urgency > rhs.1.urgency : (lhs.1.daysLeft ?? .max) < (rhs.1.daysLeft ?? .max)
            }
    }

    /// Finished shifts from the last week that still have no earnings.
    func shiftsMissingEarnings(days: Int = 7) -> [Shift] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return shifts().filter { !$0.isActive && $0.start >= since && $0.earnings.isEmpty && $0.duration > 15 * 60 }
    }

    func insights() -> [Insight] {
        let calendar = Calendar.current
        let eightWeeksAgo = calendar.date(byAdding: .day, value: -56, to: calendar.startOfDay(for: .now)) ?? .now
        let input = InsightComposer.Input(
            thisWeek: stats(.week),
            lastWeek: stats(.week, offset: -1),
            recentDays: stats(in: DateInterval(start: eightWeeksAgo, end: .now)).days,
            thisMonth: stats(.month),
            shiftsWithoutEarnings: shiftsMissingEarnings().count,
            dueReminders: reminderStatuses().filter { $0.status.urgency > .ok }.map { ($0.reminder.title, $0.status) })
        return InsightComposer(money: money).insights(input)
    }

    /// The shift a screenshot or entry taken at `date` belongs to.
    func shift(at date: Date) -> Shift? {
        // The running shift counts too: trip screenshots are taken while driving.
        let candidates = shifts()
        let index = ShiftMatcher().index(for: date, in: candidates.map { ($0.start, $0.end ?? .now) })
        return index.map { candidates[$0] }
    }

    // MARK: - Writing

    @discardableResult
    func add(_ draft: ExpenseDraft) -> Expense {
        let date = Calendar.current.date(byAdding: .day, value: -draft.daysAgo, to: .now) ?? .now
        let expense = Expense(date: date, category: draft.category, amount: draft.amount,
                              liters: draft.liters, odometerKm: draft.odometerKm, note: draft.note)
        context.insert(expense)
        if let odometer = draft.odometerKm, odometer > car.odometerKm {
            car.odometerKm = odometer
            car.odometerUpdatedAt = .now
        }
        try? context.save()
        return expense
    }

    @discardableResult
    func add(_ draft: EarningDraft, date: Date? = nil, shift: Shift? = nil) -> Earning {
        let date = date ?? Calendar.current.date(byAdding: .day, value: -draft.daysAgo, to: .now) ?? .now
        let earning = Earning(date: shift?.start ?? date, platform: draft.platform, fares: draft.fares, tips: draft.tips,
                              bonus: draft.bonus, trips: draft.trips, distanceKm: draft.distanceKm,
                              destination: draft.destination, cashCollected: draft.cashCollected, shift: shift ?? self.shift(at: date))
        context.insert(earning)
        context.addKilometers(draft.distanceKm, to: earning.shift)
        try? context.save()
        return earning
    }

    func delete(_ model: any PersistentModel) {
        context.delete(model)
        try? context.save()
    }

    // MARK: - Plain-language answers (instant, no Apple Intelligence needed)

    func answer(_ command: AssistantCommand) -> String {
        switch command {
        case let .stats(period, offset):
            return describe(stats(period, offset: offset), label: label(period, offset))
        case let .compare(period):
            return compare(period)
        case let .spending(category, period, offset):
            let stats = stats(period, offset: offset)
            let label = label(period, offset)
            let spent = money.string(stats.expenses)
            guard let category else {
                let top = stats.expensesByCategory.sorted { $0.value > $1.value }.prefix(3)
                    .map { "\($0.key.title.lowercased()) \(money.string($0.value))" }.joined(separator: ", ")
                return top.isEmpty ? String(localized: "You spent \(spent) \(label).") : String(localized: "You spent \(spent) \(label): \(top).")
            }
            let amount = money.string(stats.expensesByCategory[category] ?? 0)
            return String(localized: "You spent \(amount) on \(category.title.lowercased()) \(label).")
        case .bestDay:
            let calendar = Calendar.current
            let since = calendar.date(byAdding: .day, value: -56, to: .now) ?? .now
            guard let best = InsightComposer(money: money).bestWeekday(stats(in: DateInterval(start: since, end: .now)).days) else {
                return String(localized: "I need a few more weeks of shifts to tell which day pays best.")
            }
            return String(localized: "Over the last 8 weeks, \(best.name) pays best: about \(money.string(best.perHour)) per hour before costs.")
        case .reminders:
            let items = reminderStatuses()
            guard !items.isEmpty else { return String(localized: "You have no reminders yet. Add your ITP, RCA and vignette dates in the Car tab.") }
            return items.prefix(4).map { "• \($0.reminder.title): \(dueText($0.reminder, $0.status))" }.joined(separator: "\n")
        case .missingEarnings:
            let missing = shiftsMissingEarnings()
            guard !missing.isEmpty else { return String(localized: "All your shifts from the last week have earnings. Nice.") }
            return String(localized: "These shifts have no earnings yet:") + "\n" + missing.prefix(5).map {
                "• \($0.start.formatted(.dateTime.weekday(.wide).day().month())), \(Formatters.duration($0.duration)), \($0.distanceKm.kilometers)"
            }.joined(separator: "\n")
        case let .add(entry):
            return describe(entry)
        case .unknown:
            return String(localized: "I can answer questions like \"How much did I make this week?\", \"What's due?\" or \"Which day pays best?\", and add entries like \"fuel $40 38 L\" or \"uber 420 tips 30\".")
        }
    }

    func describe(_ stats: PeriodStats, label: String) -> String {
        guard stats.shiftCount > 0 || stats.earnings > 0 || stats.expenses > 0 else { return String(localized: "Nothing logged \(label).") }
        let title = label.prefix(1).uppercased() + label.dropFirst()
        var text = String(localized: "\(title): \(money.string(stats.net)) net (\(money.string(stats.earnings)) earned − \(money.string(stats.expenses)) costs)")
        if stats.shiftCount > 0 {
            text += String(localized: ", \(stats.shiftCount) shifts, \(Formatters.hours(stats.hours)), \(stats.km.kilometers)")
        }
        if let perHour = stats.netPerHour { text += String(localized: ". \(money.string(perHour)) net per hour") }
        if let perKm = stats.netPerKm { text += String(localized: ", \(money.string(perKm, decimals: true)) per km") }
        return text + "."
    }

    func describe(_ entry: QuickEntry) -> String {
        switch entry {
        case let .expense(draft):
            var text = "\(draft.category.title) \(money.string(draft.amount, decimals: true))"
            if let liters = draft.liters { text += ", \(liters.formatted()) \(draft.category == .charging ? "kWh" : "L")" }
            if !draft.note.isEmpty { text += String(localized: " at \(draft.note)") }
            return text + (draft.daysAgo == 1 ? String(localized: ", yesterday") : "")
        case let .earning(draft):
            var text = "\(draft.platform.title) \(money.string(draft.total, decimals: true))"
            if draft.tips > 0 { text += String(localized: " incl. \(money.string(draft.tips)) tips") }
            if draft.trips > 0 { text += String(localized: ", \(draft.trips) trips") }
            return text + (draft.daysAgo == 1 ? String(localized: ", yesterday") : "")
        }
    }

    func dueText(_ reminder: Reminder, _ status: ReminderStatus) -> String {
        var parts: [String] = []
        if let date = reminder.dueDate, let days = status.daysLeft {
            let when = date.formatted(date: .abbreviated, time: .omitted)
            parts.append(days < 0 ? String(localized: "expired on \(when)")
                         : days == 0 ? String(localized: "due today") : String(localized: "\(when) (in \(days) days)"))
        }
        if let km = status.kmLeft {
            parts.append(km <= 0 ? String(localized: "overdue by \(abs(km).kilometers)") : String(localized: "in \(km.kilometers)"))
        }
        return parts.isEmpty ? String(localized: "no date set") : parts.joined(separator: ", ")
    }

    private func compare(_ period: StatsPeriod) -> String {
        let now = stats(period), before = stats(period, offset: -1)
        let name = switch period {
        case .day: String(localized: "Today vs yesterday")
        case .week: String(localized: "This week vs last week")
        case .month: String(localized: "This month vs last month")
        case .year: String(localized: "This year vs last year")
        }
        func change(_ a: Double, _ b: Double) -> String {
            guard b != 0 else { return "" }
            let pct = (a - b) / abs(b)
            return " (\(pct >= 0 ? "+" : "−")\(abs(pct).percentString))"
        }
        var text = String(localized: "\(name): net \(money.string(now.net)) vs \(money.string(before.net))") + change(now.net, before.net)
        text += String(localized: ", earned \(money.string(now.earnings)) vs \(money.string(before.earnings))")
        if let a = now.netPerHour, let b = before.netPerHour {
            text += String(localized: ", per hour \(money.string(a)) vs \(money.string(b))") + change(a, b)
        }
        switch period {
        case .day: break
        case .week: text += String(localized: ". Note: this week isn't over yet")
        case .month: text += String(localized: ". Note: this month isn't over yet")
        case .year: text += String(localized: ". Note: this year isn't over yet")
        }
        return text + "."
    }

    /// Fits into a sentence: "You spent 120 lei *last week*."
    func label(_ period: StatsPeriod, _ offset: Int) -> String {
        let ago = abs(offset)
        return switch (period, offset) {
        case (.day, 0): String(localized: "today")
        case (.day, -1): String(localized: "yesterday")
        case (.week, 0): String(localized: "this week")
        case (.week, -1): String(localized: "last week")
        case (.month, 0): String(localized: "this month")
        case (.month, -1): String(localized: "last month")
        case (.year, 0): String(localized: "this year")
        case (.year, -1): String(localized: "last year")
        case (.day, _): String(localized: "\(ago) days ago")
        case (.week, _): String(localized: "\(ago) weeks ago")
        case (.month, _): String(localized: "\(ago) months ago")
        case (.year, _): String(localized: "\(ago) years ago")
        }
    }
}
