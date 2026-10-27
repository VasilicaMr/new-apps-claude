import Foundation

// The three "Earn smarter" tools: what the car really costs per km, how far the weekly goal is,
// and when driving pays best. Plain value inputs so the math is testable without SwiftData.

// MARK: - True cost of the car

/// What the driver tells DriveCap about the car. Zero means "not set".
struct CarCostSettings: Sendable, Hashable {
    var rentAmount: Double = 0
    /// `rentAmount` is per month (leasing) instead of per week (rent from a fleet).
    var rentPerMonth = false
    /// Insurance, phone, fleet fee and other costs that don't depend on the km.
    var otherPerMonth: Double = 0
    var carValue: Double = 0
    var resaleValue: Double = 0
    /// Km the driver expects to drive before selling the car.
    var kmUntilSale: Double = 0
    var tyreSetCost: Double = 0
    var tyreLifeKm: Double = 40_000
    var serviceCost: Double = 0
    var serviceIntervalKm: Double = 15_000
    /// Used when there are no fuel receipts yet.
    var litersPer100Km: Double = 0
    var fuelPrice: Double = 0
    /// Used when there are no trips with kilometers yet.
    var expectedWeeklyKm: Double = 0

    var rentPerWeek: Double { rentPerMonth ? rentAmount * 12 / 52 : rentAmount }
    var otherPerWeek: Double { otherPerMonth * 12 / 52 }
}

struct CarCostLine: Sendable, Hashable, Identifiable {
    enum Kind: String, Sendable, CaseIterable {
        case fuel, rent, fixed, depreciation, tyres, service

        var title: String {
            switch self {
            case .fuel: String(localized: "Fuel")
            case .rent: String(localized: "Leasing or rent")
            case .fixed: String(localized: "Insurance, phone, fees")
            case .depreciation: String(localized: "Car losing value")
            case .tyres: String(localized: "Tyres")
            case .service: String(localized: "Service")
            }
        }

        var symbol: String {
            switch self {
            case .fuel: "fuelpump.fill"
            case .rent: "doc.text.fill"
            case .fixed: "shield.fill"
            case .depreciation: "chart.line.downtrend.xyaxis"
            case .tyres: "circle.circle.fill"
            case .service: "wrench.and.screwdriver.fill"
            }
        }
    }

    let kind: Kind
    let perKm: Double

    var id: Kind { kind }
}

struct CarCostBreakdown: Sendable, Hashable {
    let lines: [CarCostLine]
    /// Km per week the fixed costs are spread over.
    let weeklyKm: Double
    /// `weeklyKm` comes from the trips logged, not the driver's estimate.
    let kmFromTrips: Bool
    let fuelFromReceipts: Bool
    /// Recent earnings per km, before costs.
    let earningsPerKm: Double?

    /// Every cost of the car spread over each km. Below this per km, a trip loses money.
    var costPerKm: Double { lines.reduce(0) { $0 + $1.perKm } }
    var profitPerKm: Double? { earningsPerKm.map { $0 - costPerKm } }
    var weeklyCost: Double { costPerKm * weeklyKm }
    /// Fuel alone isn't the true cost; at least one other cost has to be filled in.
    var isSetUp: Bool { lines.contains { $0.kind != .fuel && $0.perKm > 0 } }
    func perKm(_ kind: CarCostLine.Kind) -> Double { lines.first { $0.kind == kind }?.perKm ?? 0 }
}

struct CarCostCalculator: Sendable {
    /// - Parameters:
    ///   - recentKm: km logged over `recentWeeks`.
    ///   - recentFuelCost: fuel and charging receipts over the same time.
    ///   - recentEarnings: earnings over the same time.
    func breakdown(settings: CarCostSettings, recentKm: Double, recentWeeks: Double,
                   recentFuelCost: Double, recentEarnings: Double) -> CarCostBreakdown {
        let kmFromTrips = recentKm > 0 && recentWeeks > 0
        let weeklyKm = kmFromTrips ? recentKm / recentWeeks : settings.expectedWeeklyKm
        let fuelFromReceipts = recentFuelCost > 0 && recentKm > 0
        let fuel = fuelFromReceipts ? recentFuelCost / recentKm : settings.litersPer100Km * settings.fuelPrice / 100

        func spread(_ weekly: Double) -> Double { weeklyKm > 0 ? weekly / weeklyKm : 0 }
        func per(_ cost: Double, _ km: Double) -> Double { km > 0 ? cost / km : 0 }

        let lines = [
            CarCostLine(kind: .fuel, perKm: fuel),
            CarCostLine(kind: .rent, perKm: spread(settings.rentPerWeek)),
            CarCostLine(kind: .fixed, perKm: spread(settings.otherPerWeek)),
            CarCostLine(kind: .depreciation, perKm: per(max(0, settings.carValue - settings.resaleValue), settings.kmUntilSale)),
            CarCostLine(kind: .tyres, perKm: per(settings.tyreSetCost, settings.tyreLifeKm)),
            CarCostLine(kind: .service, perKm: per(settings.serviceCost, settings.serviceIntervalKm)),
        ]
        return CarCostBreakdown(lines: lines, weeklyKm: weeklyKm, kmFromTrips: kmFromTrips, fuelFromReceipts: fuelFromReceipts,
                                earningsPerKm: recentKm > 0 && recentEarnings > 0 ? recentEarnings / recentKm : nil)
    }
}

// MARK: - Weekly goal

struct GoalProgress: Sendable, Hashable {
    let goal: Double
    /// Kept so far this week (earned − costs).
    let net: Double
    /// Days left in the week, today included.
    let daysLeft: Int
    /// Net per hour the plan assumes, from the best day still to come this week.
    let rate: Double?
    /// 1 = Sunday, like `Calendar`. Nil when the rate is the overall average.
    let rateWeekday: Int?

    var remaining: Double { max(0, goal - net) }
    var fraction: Double { goal > 0 ? min(1, max(0, net / goal)) : 0 }
    var isReached: Bool { goal > 0 && net >= goal }
    var hoursNeeded: Double? {
        guard let rate, rate > 0, !isReached else { return nil }
        return remaining / rate
    }
}

struct GoalPlanner: Sendable {
    var calendar: Calendar = .current

    /// - Parameters:
    ///   - week: this week so far.
    ///   - weekEnd: when the week ends (`week` itself stops at today).
    ///   - history: the last weeks, for the hourly rate of each weekday.
    func progress(goal: Double, week: PeriodStats, weekEnd: Date, history: PeriodStats, now: Date) -> GoalProgress {
        let today = calendar.startOfDay(for: now)
        let daysLeft = max(1, calendar.dateComponents([.day], from: today, to: weekEnd).day ?? 1)
        let rates = netPerHourByWeekday(history)
        let upcoming = (0..<daysLeft).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map { calendar.component(.weekday, from: $0) }
        }
        let best = upcoming.compactMap { day in rates[day].map { (day, $0) } }.max { $0.1 < $1.1 }
        return GoalProgress(goal: goal, net: week.net, daysLeft: daysLeft,
                            rate: best?.1 ?? overallNetPerHour(history), rateWeekday: best?.0)
    }

    /// Earnings per hour on each weekday, minus the usual share that goes to costs.
    /// Only days with logged hours count, so earnings without a shift don't inflate the rate.
    func netPerHourByWeekday(_ history: PeriodStats) -> [Int: Double] {
        let margin = margin(history)
        var earnings: [Int: Double] = [:]
        var hours: [Int: Double] = [:]
        for day in history.days where day.hours > 0 {
            let weekday = calendar.component(.weekday, from: day.day)
            earnings[weekday, default: 0] += day.earnings
            hours[weekday, default: 0] += day.hours
        }
        return hours.reduce(into: [:]) { result, entry in
            if entry.value >= 1 { result[entry.key] = (earnings[entry.key] ?? 0) / entry.value * margin }
        }
    }

    private func overallNetPerHour(_ history: PeriodStats) -> Double? {
        let worked = history.days.filter { $0.hours > 0 }
        let hours = worked.reduce(0) { $0 + $1.hours }
        guard hours >= 1 else { return nil }
        return worked.reduce(0) { $0 + $1.earnings } / hours * margin(history)
    }

    /// The part of earnings the driver keeps after costs, between 0 and 1.
    private func margin(_ history: PeriodStats) -> Double {
        history.earnings > 0 ? min(1, max(0, history.net / history.earnings)) : 1
    }
}

// MARK: - Best times to drive

enum DayPart: Int, CaseIterable, Sendable, Identifiable, Comparable {
    case morning, afternoon, evening, night

    var id: Int { rawValue }
    var startHour: Int { [6, 12, 17, 22][rawValue] }
    var endHour: Int { [12, 17, 22, 6][rawValue] }
    var title: String {
        switch self {
        case .morning: String(localized: "Morning")
        case .afternoon: String(localized: "Afternoon")
        case .evening: String(localized: "Evening")
        case .night: String(localized: "Night")
        }
    }
    var hours: String { "\(startHour)–\(endHour)" }
    var symbol: String { ["sunrise.fill", "sun.max.fill", "sunset.fill", "moon.stars.fill"][rawValue] }

    static func < (lhs: DayPart, rhs: DayPart) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct TimeSlot: Sendable, Hashable {
    /// 1 = Sunday. Night (22–6) belongs to the evening it starts, so Friday night runs into Saturday morning.
    let weekday: Int
    let part: DayPart
}

/// A finished shift with what each app paid during it.
struct ShiftEarningsFigures: Sendable, Hashable {
    let start: Date
    let end: Date
    let byPlatform: [Platform: Double]

    var total: Double { byPlatform.values.reduce(0, +) }
}

struct SlotRate: Sendable, Hashable, Identifiable {
    let slot: TimeSlot
    let earnings: Double
    let hours: Double
    let appEarnings: [Platform: Double]
    let appHours: [Platform: Double]

    var id: TimeSlot { slot }
    var perHour: Double { hours > 0 ? earnings / hours : 0 }

    func perHour(_ platform: Platform) -> Double? {
        guard let hours = appHours[platform], hours >= 1 else { return nil }
        return (appEarnings[platform] ?? 0) / hours
    }

    /// The app that paid clearly more per hour in this slot (at least 5% more than the next one).
    var bestApp: Platform? {
        let rates = appHours.keys.compactMap { app in perHour(app).map { (app, $0) } }.sorted { $0.1 > $1.1 }
        guard rates.count > 1, rates[0].1 >= rates[1].1 * 1.05 else { return nil }
        return rates[0].0
    }
}

struct AppRate: Sendable, Hashable, Identifiable {
    let platform: Platform
    let perHour: Double?
    let perKm: Double?

    var id: Platform { platform }
}

struct BestTimesReport: Sendable, Hashable {
    /// Every slot with some driving in it.
    let slots: [TimeSlot: SlotRate]
    /// Slots with enough hours to trust, best first.
    let ranked: [SlotRate]
    let apps: [AppRate]
    let minimumHours: Double

    var best: SlotRate? { ranked.first }
    var slowest: SlotRate? { ranked.count > 2 ? ranked.last : nil }
    var hasEnoughData: Bool { !ranked.isEmpty }

    func isTrusted(_ rate: SlotRate) -> Bool { rate.hours >= minimumHours }
}

struct BestTimesCalculator: Sendable {
    var calendar: Calendar = .current
    /// Hours a slot needs before it's ranked; one lucky trip shouldn't make a slot look great.
    var minimumHours: Double = 3

    func report(shifts: [ShiftEarningsFigures], earnings: [EarningFigures]) -> BestTimesReport {
        var earningsBySlot: [TimeSlot: Double] = [:]
        var hoursBySlot: [TimeSlot: Double] = [:]
        var appEarnings: [TimeSlot: [Platform: Double]] = [:]
        var appHours: [TimeSlot: [Platform: Double]] = [:]
        var totalAppEarnings: [Platform: Double] = [:]
        var totalAppHours: [Platform: Double] = [:]

        for shift in shifts where shift.end > shift.start && shift.total > 0 {
            let duration = shift.end.timeIntervalSince(shift.start)
            var cursor = shift.start
            while cursor < shift.end {
                let (slot, boundary) = slot(containing: cursor)
                // Always move forward, even if a clock change makes the boundary odd.
                let segmentEnd = boundary > cursor ? min(boundary, shift.end) : shift.end
                let seconds = segmentEnd.timeIntervalSince(cursor)
                let share = seconds / duration
                let hours = seconds / 3600
                earningsBySlot[slot, default: 0] += shift.total * share
                hoursBySlot[slot, default: 0] += hours
                // When both apps ran in one shift, each gets the hours in proportion to what it paid.
                for (platform, amount) in shift.byPlatform where amount > 0 {
                    let appShare = amount / shift.total
                    appEarnings[slot, default: [:]][platform, default: 0] += amount * share
                    appHours[slot, default: [:]][platform, default: 0] += hours * appShare
                    totalAppEarnings[platform, default: 0] += amount * share
                    totalAppHours[platform, default: 0] += hours * appShare
                }
                cursor = segmentEnd
            }
        }

        let slots = hoursBySlot.reduce(into: [TimeSlot: SlotRate]()) { result, entry in
            result[entry.key] = SlotRate(slot: entry.key, earnings: earningsBySlot[entry.key] ?? 0, hours: entry.value,
                                         appEarnings: appEarnings[entry.key] ?? [:], appHours: appHours[entry.key] ?? [:])
        }
        let ranked = slots.values.filter { $0.hours >= minimumHours }.sorted { $0.perHour > $1.perHour }

        var kmByApp: [Platform: Double] = [:]
        var paidByApp: [Platform: Double] = [:]
        for earning in earnings where earning.distanceKm > 0 {
            kmByApp[earning.platform, default: 0] += earning.distanceKm
            paidByApp[earning.platform, default: 0] += earning.total
        }
        let apps = Set(totalAppHours.keys).union(kmByApp.keys).map { platform in
            AppRate(platform: platform,
                    perHour: (totalAppHours[platform] ?? 0) >= 1 ? (totalAppEarnings[platform] ?? 0) / totalAppHours[platform]! : nil,
                    perKm: (kmByApp[platform] ?? 0) > 0 ? (paidByApp[platform] ?? 0) / kmByApp[platform]! : nil)
        }
        .sorted { ($0.perHour ?? 0) > ($1.perHour ?? 0) }

        return BestTimesReport(slots: slots, ranked: ranked, apps: apps, minimumHours: minimumHours)
    }

    /// The slot a moment falls in, and when that slot ends.
    func slot(containing date: Date) -> (TimeSlot, Date) {
        let day = calendar.startOfDay(for: date)
        let hour = calendar.component(.hour, from: date)
        // Wall-clock hours, so the day the clocks change still ends its morning at 12:00.
        func at(_ hour: Int, dayOffset: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: dayOffset, to: day) ?? day
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base.addingTimeInterval(Double(hour) * 3600)
        }
        let weekday = calendar.component(.weekday, from: day)
        switch hour {
        case ..<6:
            let previous = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            return (TimeSlot(weekday: calendar.component(.weekday, from: previous), part: .night), at(6))
        case 6..<12: return (TimeSlot(weekday: weekday, part: .morning), at(12))
        case 12..<17: return (TimeSlot(weekday: weekday, part: .afternoon), at(17))
        case 17..<22: return (TimeSlot(weekday: weekday, part: .evening), at(22))
        default: return (TimeSlot(weekday: weekday, part: .night), at(6, dayOffset: 1))
        }
    }
}
