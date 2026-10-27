import Foundation

/// Feeds the Earn smarter tools from the stored data: the last 4 weeks for the car's cost per km,
/// the last 8 weeks for hourly rates and the best times to drive.
struct MoneyPlan {
    let week: PeriodStats
    let carCost: CarCostBreakdown
    /// Nil when no weekly goal is set.
    let goal: GoalProgress?
    let bestTimes: BestTimesReport
    /// Net per hour on each weekday (1 = Sunday), for the goal's day-by-day plan.
    let weekdayRates: [Int: Double]

    @MainActor
    init(shifts: [Shift], earnings: [Earning], expenses: [Expense], car: Car?, weeklyGoal: Double,
         now: Date = .now, calendar: Calendar = .current) {
        let calculator = StatsCalculator(calendar: calendar)
        let finished = shifts.filter { !$0.isActive }
        let shiftFigures = finished.map(\.figures)
        let earningFigures = earnings.map(\.figures)
        let expenseFigures = expenses.map(\.figures)
        // Stop at the end of today so costs spread over months aren't charged for days still to come.
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        func lastDays(_ days: Int) -> DateInterval {
            DateInterval(start: calendar.date(byAdding: .day, value: -days, to: endOfToday) ?? endOfToday, end: endOfToday)
        }
        func stats(_ interval: DateInterval) -> PeriodStats {
            calculator.stats(in: interval, shifts: shiftFigures, earnings: earningFigures, expenses: expenseFigures)
        }

        let weekInterval = StatsPeriod.week.interval(containing: now, calendar: calendar)
        week = stats(DateInterval(start: weekInterval.start, end: max(weekInterval.start, min(weekInterval.end, endOfToday))))

        // A new driver with 5 days of trips drives 5 days' km a week, not a quarter of it.
        let recent = stats(lastDays(28))
        let firstDay = finished.map(\.start).filter { $0 >= recent.interval.start }.min()
        let recentDays = firstDay.map { endOfToday.timeIntervalSince(calendar.startOfDay(for: $0)) / 86_400 } ?? 28
        carCost = CarCostCalculator().breakdown(
            settings: car?.costSettings ?? CarCostSettings(),
            recentKm: recent.km, recentWeeks: max(1, recentDays / 7),
            recentFuelCost: (recent.expensesByCategory[.fuel] ?? 0) + (recent.expensesByCategory[.charging] ?? 0),
            recentEarnings: recent.earnings)

        let history = stats(lastDays(56))
        let planner = GoalPlanner(calendar: calendar)
        weekdayRates = planner.netPerHourByWeekday(history)
        goal = weeklyGoal > 0
            ? planner.progress(goal: weeklyGoal, week: week, weekEnd: weekInterval.end, history: history, now: now)
            : nil

        let since = history.interval.start
        bestTimes = BestTimesCalculator(calendar: calendar).report(
            shifts: finished.filter { $0.start >= since }.map { shift in
                ShiftEarningsFigures(start: shift.start, end: shift.end ?? shift.start,
                                     byPlatform: shift.earnings.reduce(into: [:]) { $0[$1.platform, default: 0] += $1.total })
            },
            earnings: earningFigures.filter { $0.date >= since })
    }
}
