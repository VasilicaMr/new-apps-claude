import Foundation
import SwiftData

// Everything is stored on this iPhone only. Enums are kept as raw strings so adding a case
// later never breaks existing data.

@Model
final class Shift {
    var start: Date
    var end: Date?
    /// Kilometers driven, added up from the trips read off Uber/Bolt screenshots or typed in.
    var distanceMeters: Double
    var isManual: Bool
    var note: String
    @Relationship(deleteRule: .nullify, inverse: \Earning.shift) var earnings: [Earning] = []

    init(start: Date, end: Date? = nil, distanceMeters: Double = 0, isManual: Bool = false, note: String = "") {
        self.start = start
        self.end = end
        self.distanceMeters = distanceMeters
        self.isManual = isManual
        self.note = note
    }

    var isActive: Bool { end == nil }
    var distanceKm: Double { distanceMeters / 1000 }
    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
    var earningsTotal: Double { earnings.reduce(0) { $0 + $1.total } }

    var figures: ShiftFigures {
        ShiftFigures(start: start, end: end ?? .now, distanceKm: distanceKm)
    }
}

@Model
final class Earning {
    var date: Date
    var platformRaw: String
    var fares: Double
    var tips: Double
    var bonus: Double
    var trips: Int
    /// Kilometers shown on the screenshot (trip distance, or the day's/week's total). 0 if unknown.
    var distanceKm: Double = 0
    /// Drop-off address of a single trip, when the screenshot shows one.
    var destination: String = ""
    /// Part of the total paid in cash by passengers; the app pays out `total - cashCollected`.
    var cashCollected: Double = 0
    var note: String
    var shift: Shift?

    init(date: Date, platform: Platform, fares: Double, tips: Double = 0, bonus: Double = 0,
         trips: Int = 0, distanceKm: Double = 0, destination: String = "", cashCollected: Double = 0,
         note: String = "", shift: Shift? = nil) {
        self.date = date
        self.platformRaw = platform.rawValue
        self.fares = fares
        self.tips = tips
        self.bonus = bonus
        self.trips = trips
        self.distanceKm = distanceKm
        self.destination = destination
        self.cashCollected = cashCollected
        self.note = note
        self.shift = shift
    }

    var platform: Platform {
        get { Platform(rawValue: platformRaw) ?? .other }
        set { platformRaw = newValue.rawValue }
    }

    var total: Double { fares + tips + bonus }

    var figures: EarningFigures {
        EarningFigures(date: date, platform: platform, fares: fares, tips: tips, bonus: bonus, trips: trips, cash: cashCollected,
                       distanceKm: distanceKm)
    }
}

@Model
final class Expense {
    var date: Date
    var categoryRaw: String
    var amount: Double
    var coverageMonths: Int
    var liters: Double?
    var odometerKm: Double?
    var note: String
    @Attribute(.externalStorage) var receipt: Data?

    init(date: Date, category: ExpenseCategory, amount: Double, coverageMonths: Int? = nil,
         liters: Double? = nil, odometerKm: Double? = nil, note: String = "", receipt: Data? = nil) {
        self.date = date
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.coverageMonths = coverageMonths ?? category.defaultCoverageMonths
        self.liters = liters
        self.odometerKm = odometerKm
        self.note = note
        self.receipt = receipt
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var figures: ExpenseFigures {
        ExpenseFigures(date: date, category: category, amount: amount, coverageMonths: coverageMonths)
    }
}

@Model
final class Reminder {
    var id: UUID
    var kindRaw: String
    var title: String
    var dueDate: Date?
    var dueKm: Double?
    var repeatMonths: Int?
    var repeatKm: Double?
    var note: String

    init(kind: ReminderKind, title: String? = nil, dueDate: Date? = nil, dueKm: Double? = nil,
         repeatMonths: Int? = nil, repeatKm: Double? = nil, note: String = "") {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.title = title ?? kind.title
        self.dueDate = dueDate
        self.dueKm = dueKm
        self.repeatMonths = repeatMonths
        self.repeatKm = repeatKm
        self.note = note
    }

    var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var rule: DueRule {
        get { DueRule(dueDate: dueDate, dueKm: dueKm, repeatMonths: repeatMonths, repeatKm: repeatKm) }
        set {
            dueDate = newValue.dueDate
            dueKm = newValue.dueKm
            repeatMonths = newValue.repeatMonths
            repeatKm = newValue.repeatKm
        }
    }
}

/// The driver's car. Phase 1 supports one car; the odometer grows with the kilometers logged.
@Model
final class Car {
    var name: String
    var plate: String
    var odometerKm: Double
    var odometerUpdatedAt: Date

    // True cost of the car (Home → Earn smarter → Car cost). Zero means not set.
    var rentAmount: Double = 0
    var rentPerMonth: Bool = false
    var otherMonthlyCosts: Double = 0
    var carValue: Double = 0
    var resaleValue: Double = 0
    var kmUntilSale: Double = 0
    var tyreSetCost: Double = 0
    var tyreLifeKm: Double = 40_000
    var serviceCost: Double = 0
    var serviceIntervalKm: Double = 15_000
    var litersPer100Km: Double = 0
    var fuelPrice: Double = 0
    var expectedWeeklyKm: Double = 0

    init(name: String = "", plate: String = "", odometerKm: Double = 0) {
        self.name = name
        self.plate = plate
        self.odometerKm = odometerKm
        self.odometerUpdatedAt = .now
    }

    var costSettings: CarCostSettings {
        CarCostSettings(rentAmount: rentAmount, rentPerMonth: rentPerMonth, otherPerMonth: otherMonthlyCosts,
                        carValue: carValue, resaleValue: resaleValue, kmUntilSale: kmUntilSale,
                        tyreSetCost: tyreSetCost, tyreLifeKm: tyreLifeKm, serviceCost: serviceCost,
                        serviceIntervalKm: serviceIntervalKm, litersPer100Km: litersPer100Km, fuelPrice: fuelPrice,
                        expectedWeeklyKm: expectedWeeklyKm)
    }
}

/// "This was read wrong": the text read from a screenshot (never the image), what DriveCap understood,
/// and what the driver corrected it to. Kept on the phone; the driver can export and share it to improve reading.
@Model
final class ScanReport {
    var date: Date
    var method: String
    var detected: String
    var corrected: String?
    var recognizedText: String

    init(result: ScreenshotEarnings, date: Date = .now) {
        self.date = date
        self.method = result.source == .appleIntelligence ? "Apple Intelligence" : "Text matching"
        self.detected = result.summary
        self.recognizedText = result.recognizedLines.joined(separator: "\n")
    }

    var text: String {
        """
        DriveCap screenshot report — \(date.formatted(.iso8601))
        Method: \(method)
        Detected: \(detected)
        Corrected: \(corrected ?? "(not saved)")
        --- Text read from the screenshot ---
        \(recognizedText)
        """
    }
}

enum DataStore {
    static let models: [any PersistentModel.Type] = [Shift.self, Earning.self, Expense.self, Reminder.self, Car.self, ScanReport.self]

    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }
}

extension ModelContext {
    /// The single car record, created on first use.
    func car() -> Car {
        if let car = try? fetch(FetchDescriptor<Car>()).first { return car }
        let car = Car()
        insert(car)
        return car
    }

    /// Adds kilometers read from a trip to its shift and to the car's odometer.
    /// Negative takes them back (an edited or deleted entry).
    func addKilometers(_ km: Double, to shift: Shift?) {
        guard km != 0 else { return }
        if let shift { shift.distanceMeters = max(0, shift.distanceMeters + km * 1000) }
        let car = car()
        car.odometerKm = max(0, car.odometerKm + km)
        car.odometerUpdatedAt = .now
    }
}
