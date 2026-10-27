#if DEBUG
import Foundation
import SwiftData

/// Six weeks of believable ride-sharing data in Bucharest, for previews, screenshots and testing.
/// Launch with `-seedSampleData` to replace the local database with it.
@MainActor
enum SampleData {
    static func reset(_ context: ModelContext, now: Date = .now) {
        for model in DataStore.models { try? context.delete(model: model) }
        insert(into: context, now: now)
        try? context.save()
    }

    static func insert(into context: ModelContext, now: Date = .now) {
        var random = SeededGenerator(seed: 42)
        // Amounts are in lei; other currencies get believable local numbers (and fuel prices) for screenshots.
        let currency = UserDefaults.standard.string(forKey: SettingsKeys.currencyCode) ?? MoneyFormatter.defaultCurrencyCode
        let (scale, fuelPerLiter): (Double, Double) = switch currency {
        case "USD": (0.6, 1.0)
        case "EUR": (0.4, 1.75)
        default: (1, 7.35)
        }
        func money(_ lei: Double) -> Double { (lei * scale).rounded() }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let car = Car(name: "Toyota Corolla Hybrid", plate: "B 123 DRV", odometerKm: 0)
        car.otherMonthlyCosts = money(250)
        car.carValue = money(75_000)
        car.resaleValue = money(35_000)
        car.kmUntilSale = 200_000
        car.tyreSetCost = money(2_400)
        car.tyreLifeKm = 50_000
        car.serviceCost = money(900)
        context.insert(car)
        var odometer = 148_200.0

        for daysAgo in stride(from: 42, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day) // 1 = Sunday
            if weekday == 3 && daysAgo % 2 == 0 { continue } // a few days off

            let isWeekendNight = weekday == 6 || weekday == 7
            let startHour = isWeekendNight ? 17 : (daysAgo % 3 == 0 ? 6 : 8)
            let hours = Double.random(in: 7...10, using: &random)
            let start = day.addingTimeInterval(Double(startHour) * 3600 + Double.random(in: 0...1800, using: &random))
            let end = start.addingTimeInterval(hours * 3600)
            if end > now { continue }
            let km = hours * Double.random(in: 19...27, using: &random)
            let shift = Shift(start: start, end: end, distanceMeters: km * 1000)
            context.insert(shift)
            odometer += km

            let perHour = (isWeekendNight ? 58.0 : 44.0) * Double.random(in: 0.85...1.2, using: &random)
            let gross = perHour * hours * scale
            let uberShare = Double.random(in: 0.55...0.8, using: &random)
            let trips = Int(hours * Double.random(in: 1.6...2.4, using: &random))
            context.insert(Earning(date: start, platform: .uber, fares: (gross * uberShare).rounded(),
                                   tips: money(Double(Int.random(in: 0...35, using: &random))),
                                   bonus: daysAgo % 7 == 0 ? money(120) : 0,
                                   trips: Int(Double(trips) * uberShare), distanceKm: (km * uberShare).rounded(), shift: shift))
            context.insert(Earning(date: start, platform: .bolt, fares: (gross * (1 - uberShare)).rounded(),
                                   tips: money(Double(Int.random(in: 0...15, using: &random))),
                                   trips: trips - Int(Double(trips) * uberShare), distanceKm: (km * (1 - uberShare)).rounded(),
                                   shift: shift))

            if daysAgo % 3 == 0 {
                let liters = Double.random(in: 30...42, using: &random).rounded()
                context.insert(Expense(date: end.addingTimeInterval(-1800), category: .fuel, amount: (liters * fuelPerLiter).rounded(),
                                       liters: liters, odometerKm: odometer.rounded(), note: "Petrom"))
            }
            if daysAgo % 6 == 0 {
                context.insert(Expense(date: start, category: .carWash, amount: money(35)))
            }
        }

        context.insert(Expense(date: calendar.date(byAdding: .day, value: -30, to: today)!, category: .insurance, amount: money(1_640), note: "RCA, 12 months"))
        context.insert(Expense(date: calendar.date(byAdding: .day, value: -20, to: today)!, category: .maintenance, amount: money(780), note: "Oil + filters + brake pads"))
        context.insert(Expense(date: calendar.date(byAdding: .day, value: -12, to: today)!, category: .parking, amount: money(18)))
        context.insert(Expense(date: calendar.date(byAdding: .day, value: -9, to: today)!, category: .fines, amount: money(145), note: "Bus lane"))
        context.insert(Expense(date: calendar.date(byAdding: .day, value: -25, to: today)!, category: .phone, amount: money(60), coverageMonths: 1, note: "Data plan"))
        car.odometerKm = odometer.rounded()

        let reminders = [
            Reminder(kind: .inspection, dueDate: calendar.date(byAdding: .day, value: 12, to: today), repeatMonths: 6),
            Reminder(kind: .liabilityInsurance, dueDate: calendar.date(byAdding: .month, value: 11, to: today), repeatMonths: 12),
            Reminder(kind: .vignette, dueDate: calendar.date(byAdding: .day, value: -2, to: today), repeatMonths: 12),
            Reminder(kind: .oilChange, dueKm: odometer.rounded() + 650, repeatKm: 15_000),
            Reminder(kind: .rideSharePermit, dueDate: calendar.date(byAdding: .month, value: 4, to: today)),
        ]
        reminders.forEach(context.insert)
    }
}

/// Deterministic random numbers so sample data looks the same on every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
