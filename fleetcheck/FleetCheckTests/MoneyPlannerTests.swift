import Foundation
import Testing
@testable import FleetCheck

@Suite("Earn smarter")
struct MoneyPlannerTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// October 2026: the 5th is a Monday.
    func date(_ day: Int, _ hour: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    // MARK: - Car cost

    @Test func carCostPerKm() {
        var settings = CarCostSettings()
        settings.rentAmount = 500            // per week
        settings.carValue = 60_000
        settings.resaleValue = 30_000
        settings.kmUntilSale = 150_000       // 0.20 / km
        settings.tyreSetCost = 2_000         // 0.05 / km over 40,000
        settings.serviceCost = 900           // 0.06 / km over 15,000
        let cost = CarCostCalculator().breakdown(settings: settings, recentKm: 4_000, recentWeeks: 4,
                                                 recentFuelCost: 2_400, recentEarnings: 13_200)

        #expect(cost.weeklyKm == 1_000)
        #expect(cost.kmFromTrips && cost.fuelFromReceipts)
        #expect(abs(cost.perKm(.fuel) - 0.60) < 0.0001)
        #expect(abs(cost.perKm(.rent) - 0.50) < 0.0001)
        #expect(abs(cost.perKm(.depreciation) - 0.20) < 0.0001)
        #expect(abs(cost.costPerKm - 1.41) < 0.0001)
        #expect(abs((cost.earningsPerKm ?? 0) - 3.30) < 0.0001)
        #expect(abs((cost.profitPerKm ?? 0) - 1.89) < 0.0001)
        #expect(cost.isSetUp)
    }

    @Test func carCostFallsBackToEstimates() {
        var settings = CarCostSettings()
        settings.litersPer100Km = 6
        settings.fuelPrice = 7.5
        settings.rentAmount = 2_600
        settings.rentPerMonth = true        // 600 a week
        settings.expectedWeeklyKm = 1_200
        let cost = CarCostCalculator().breakdown(settings: settings, recentKm: 0, recentWeeks: 4, recentFuelCost: 0, recentEarnings: 0)

        #expect(!cost.kmFromTrips && !cost.fuelFromReceipts)
        #expect(abs(cost.perKm(.fuel) - 0.45) < 0.0001)
        #expect(abs(cost.perKm(.rent) - 0.50) < 0.0001)
        #expect(cost.earningsPerKm == nil)
    }

    @Test func fuelAloneIsNotSetUp() {
        let cost = CarCostCalculator().breakdown(settings: CarCostSettings(), recentKm: 500, recentWeeks: 1,
                                                 recentFuelCost: 300, recentEarnings: 1_500)
        #expect(!cost.isSetUp)
        #expect(cost.costPerKm == 0.6)
    }

    // MARK: - Weekly goal

    /// Two past weeks: Mondays at 40/h, Saturdays at 60/h, 10 h each, no costs.
    func history() -> PeriodStats {
        let days = [5, 10, 12, 17]
        return StatsCalculator(calendar: calendar).stats(
            in: DateInterval(start: date(5), end: date(19)),
            shifts: days.map { ShiftFigures(start: date($0, 8), end: date($0, 18), distanceKm: 200) },
            earnings: days.map { EarningFigures(date: date($0, 8), platform: .uber, fares: [5, 12].contains($0) ? 400 : 600,
                                                tips: 0, bonus: 0, trips: 10) },
            expenses: [])
    }

    @Test func goalUsesBestDayLeft() {
        let planner = GoalPlanner(calendar: calendar)
        let week = StatsCalculator(calendar: calendar).stats(
            in: DateInterval(start: date(19), end: date(22)),
            shifts: [], earnings: [EarningFigures(date: date(19, 9), platform: .bolt, fares: 1_860, tips: 0, bonus: 0, trips: 30)],
            expenses: [])
        // Wednesday 21st: Saturday is still to come.
        let goal = planner.progress(goal: 2_500, week: week, weekEnd: date(26), history: history(), now: date(21, 10))

        #expect(goal.remaining == 640)
        #expect(goal.daysLeft == 5)
        #expect(goal.rateWeekday == 7)
        #expect(goal.rate == 60)
        #expect(abs((goal.hoursNeeded ?? 0) - 640.0 / 60) < 0.0001)
        #expect(!goal.isReached)
    }

    @Test func goalReached() {
        let week = StatsCalculator(calendar: calendar).stats(
            in: DateInterval(start: date(19), end: date(22)), shifts: [],
            earnings: [EarningFigures(date: date(19, 9), platform: .bolt, fares: 3_000, tips: 0, bonus: 0, trips: 30)], expenses: [])
        let goal = GoalPlanner(calendar: calendar).progress(goal: 2_500, week: week, weekEnd: date(26), history: history(), now: date(21))
        #expect(goal.isReached)
        #expect(goal.fraction == 1)
        #expect(goal.hoursNeeded == nil)
    }

    @Test func weekdayRatesTakeOffCosts() {
        let history = StatsCalculator(calendar: calendar).stats(
            in: DateInterval(start: date(5), end: date(12)),
            shifts: [ShiftFigures(start: date(5, 8), end: date(5, 18), distanceKm: 200)],
            earnings: [EarningFigures(date: date(5, 8), platform: .uber, fares: 500, tips: 0, bonus: 0, trips: 10)],
            expenses: [ExpenseFigures(date: date(5, 12), category: .fuel, amount: 100, coverageMonths: 0)])
        // 50/h earned, 80% kept.
        #expect(GoalPlanner(calendar: calendar).netPerHourByWeekday(history)[2] == 40)
    }

    // MARK: - Best times

    @Test func nightBelongsToTheEveningItStarts() {
        let times = BestTimesCalculator(calendar: calendar)
        // Saturday 3 AM is Friday night.
        #expect(times.slot(containing: date(10, 3)).0 == TimeSlot(weekday: 6, part: .night))
        #expect(times.slot(containing: date(9, 23)).0 == TimeSlot(weekday: 6, part: .night))
        #expect(times.slot(containing: date(9, 18)).0 == TimeSlot(weekday: 6, part: .evening))
        #expect(times.slot(containing: date(9, 18)).1 == date(9, 22))
    }

    @Test func ranksSlotsAndApps() {
        let shifts = [
            // Friday 17–22 on Bolt: 80/h.
            ShiftEarningsFigures(start: date(9, 17), end: date(9, 22), byPlatform: [.bolt: 400]),
            // Monday 8–12 on Uber: 40/h.
            ShiftEarningsFigures(start: date(5, 8), end: date(5, 12), byPlatform: [.uber: 160]),
            // Monday 12–17, both apps: 50/h.
            ShiftEarningsFigures(start: date(5, 12), end: date(5, 17), byPlatform: [.uber: 150, .bolt: 100]),
            // Too short to rank.
            ShiftEarningsFigures(start: date(6, 20), end: date(6, 21), byPlatform: [.uber: 200]),
        ]
        let report = BestTimesCalculator(calendar: calendar).report(
            shifts: shifts,
            earnings: [EarningFigures(date: date(9, 17), platform: .bolt, fares: 400, tips: 0, bonus: 0, trips: 8, distanceKm: 100),
                       EarningFigures(date: date(5, 8), platform: .uber, fares: 160, tips: 0, bonus: 0, trips: 5, distanceKm: 80)])

        #expect(report.ranked.map(\.slot) == [TimeSlot(weekday: 6, part: .evening),
                                              TimeSlot(weekday: 2, part: .afternoon),
                                              TimeSlot(weekday: 2, part: .morning)])
        #expect(report.best?.perHour == 80)
        #expect(report.slowest?.perHour == 40)
        #expect(report.slots[TimeSlot(weekday: 3, part: .evening)] != nil)
        #expect(report.ranked.contains { $0.slot.weekday == 3 } == false)
        #expect(report.apps.first { $0.platform == .bolt }?.perKm == 4)
        #expect(report.apps.first { $0.platform == .uber }?.perKm == 2)
    }

    @Test func bestAppNeedsAClearGap() {
        func rate(uber: Double, bolt: Double) -> SlotRate {
            SlotRate(slot: TimeSlot(weekday: 2, part: .morning), earnings: uber + bolt, hours: 4,
                     appEarnings: [.uber: uber, .bolt: bolt], appHours: [.uber: 2, .bolt: 2])
        }
        #expect(rate(uber: 100, bolt: 102).bestApp == nil)
        #expect(rate(uber: 100, bolt: 120).bestApp == .bolt)
    }

    /// 25 October 2026 has 25 hours in Bucharest (clocks go back at 4 AM).
    @Test func survivesClockChange() {
        let times = BestTimesCalculator(calendar: calendar)
        #expect(times.slot(containing: date(25, 11)).1 == date(25, 12))
        let report = BestTimesCalculator(calendar: calendar, minimumHours: 1).report(
            shifts: [ShiftEarningsFigures(start: date(24, 20), end: date(25, 14), byPlatform: [.uber: 900])], earnings: [])
        let hours = report.slots.values.reduce(0) { $0 + $1.hours }
        #expect(abs(hours - 19) < 0.0001)
    }

    @Test func splitsShiftAcrossSlots() {
        // Friday 20:00 → Saturday 02:00: 2 h evening, 4 h night, 60/h throughout.
        let report = BestTimesCalculator(calendar: calendar, minimumHours: 1).report(
            shifts: [ShiftEarningsFigures(start: date(9, 20), end: date(10, 2), byPlatform: [.uber: 360])], earnings: [])
        let evening = report.slots[TimeSlot(weekday: 6, part: .evening)]
        let night = report.slots[TimeSlot(weekday: 6, part: .night)]
        #expect(evening?.hours == 2)
        #expect(night?.hours == 4)
        #expect(abs((night?.earnings ?? 0) - 240) < 0.0001)
    }
}
