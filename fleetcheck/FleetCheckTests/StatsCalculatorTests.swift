import Foundation
import Testing
@testable import FleetCheck

@Suite("Stats")
struct StatsCalculatorTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        calendar.firstWeekday = 2
        return calendar
    }()

    func date(_ day: Int, _ hour: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    var calculator: StatsCalculator { StatsCalculator(calendar: calendar) }

    @Test func totalsAndRates() {
        let week = DateInterval(start: date(5), end: date(12))
        let stats = calculator.stats(
            in: week,
            shifts: [ShiftFigures(start: date(6, 8), end: date(6, 18), distanceKm: 200, movingHours: 6)],
            earnings: [EarningFigures(date: date(6, 8), platform: .uber, fares: 400, tips: 20, bonus: 0, trips: 15),
                       EarningFigures(date: date(6, 8), platform: .bolt, fares: 100, tips: 0, bonus: 30, trips: 4)],
            expenses: [ExpenseFigures(date: date(6, 12), category: .fuel, amount: 150, coverageMonths: 0)])

        #expect(stats.earnings == 550)
        #expect(stats.expenses == 150)
        #expect(stats.net == 400)
        #expect(stats.hours == 10)
        #expect(stats.netPerHour == 40)
        #expect(stats.netPerKm == 2)
        #expect(stats.earningsByPlatform[.uber] == 420)
        #expect(stats.trips == 19)
        #expect(stats.movingShare == 0.6)
        #expect(stats.days.count == 7)
        #expect(stats.days[1].net == 400)
    }

    @Test("A night shift belongs to the day it started")
    func nightShiftBelongsToStartDay() {
        let shift = ShiftFigures(start: date(9, 20), end: date(10, 4), distanceKm: 120, movingHours: 5)
        let friday = calculator.stats(in: DateInterval(start: date(9), end: date(10)), shifts: [shift], earnings: [], expenses: [])
        let saturday = calculator.stats(in: DateInterval(start: date(10), end: date(11)), shifts: [shift], earnings: [], expenses: [])
        #expect(friday.km == 120)
        #expect(friday.hours == 8)
        #expect(saturday.km == 0)
    }

    @Test("Yearly insurance is spread over the year")
    func coverageIsAmortized() {
        let insurance = ExpenseFigures(date: date(1, month: 1), category: .insurance, amount: 3650, coverageMonths: 12)
        let oneDay = calculator.amount(of: insurance, in: DateInterval(start: date(6), end: date(7)))
        #expect(abs(oneDay - 10) < 0.01) // 3650 / 365
        let wholeYear = calculator.amount(of: insurance, in: DateInterval(start: date(1, month: 1), end: calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!))
        #expect(abs(wholeYear - 3650) < 0.01)
        let before = calculator.amount(of: insurance, in: DateInterval(start: date(1, month: 1).addingTimeInterval(-86_400 * 10), end: date(1, month: 1)))
        #expect(before == 0)
    }

    @Test func emptyPeriodHasNoRates() {
        let stats = calculator.stats(in: DateInterval(start: date(1), end: date(2)), shifts: [], earnings: [], expenses: [])
        #expect(stats.netPerHour == nil)
        #expect(stats.netPerKm == nil)
        #expect(stats.net == 0)
    }

    @Test func periodsStepBackwards() {
        let now = date(14, 12)
        let lastWeek = StatsPeriod.week.interval(offset: -1, from: now, calendar: calendar)
        #expect(lastWeek.start == date(5)) // Monday 5 Oct
        #expect(lastWeek.end == date(12))
        let month = StatsPeriod.month.interval(offset: 0, from: now, calendar: calendar)
        #expect(month.start == date(1))
    }
}
