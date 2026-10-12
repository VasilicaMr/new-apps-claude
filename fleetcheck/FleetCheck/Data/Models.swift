import Foundation
import SwiftData

// Everything is stored on this iPhone only. Enums are kept as raw strings so adding a case
// later never breaks existing data.

@Model
final class Shift {
    var start: Date
    var end: Date?
    var distanceMeters: Double
    var movingSeconds: Double
    var isManual: Bool
    var note: String
    @Attribute(.externalStorage) var routeData: Data
    @Relationship(deleteRule: .nullify, inverse: \Earning.shift) var earnings: [Earning] = []

    init(start: Date, end: Date? = nil, distanceMeters: Double = 0, movingSeconds: Double = 0,
         isManual: Bool = false, note: String = "", route: [RoutePoint] = []) {
        self.start = start
        self.end = end
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.isManual = isManual
        self.note = note
        self.routeData = RoutePoint.encode(route)
    }

    var isActive: Bool { end == nil }
    var distanceKm: Double { distanceMeters / 1000 }
    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
    var earningsTotal: Double { earnings.reduce(0) { $0 + $1.total } }

    var route: [RoutePoint] {
        get { RoutePoint.decode(routeData) }
        set { routeData = RoutePoint.encode(newValue) }
    }

    var figures: ShiftFigures {
        ShiftFigures(start: start, end: end ?? .now, distanceKm: distanceKm, movingHours: movingSeconds / 3600)
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
    var note: String
    var shift: Shift?

    init(date: Date, platform: Platform, fares: Double, tips: Double = 0, bonus: Double = 0,
         trips: Int = 0, note: String = "", shift: Shift? = nil) {
        self.date = date
        self.platformRaw = platform.rawValue
        self.fares = fares
        self.tips = tips
        self.bonus = bonus
        self.trips = trips
        self.note = note
        self.shift = shift
    }

    var platform: Platform {
        get { Platform(rawValue: platformRaw) ?? .other }
        set { platformRaw = newValue.rawValue }
    }

    var total: Double { fares + tips + bonus }

    var figures: EarningFigures {
        EarningFigures(date: date, platform: platform, fares: fares, tips: tips, bonus: bonus, trips: trips)
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

/// The driver's car. Phase 1 supports one car; the odometer grows with every tracked shift.
@Model
final class Car {
    var name: String
    var plate: String
    var odometerKm: Double
    var odometerUpdatedAt: Date

    init(name: String = "", plate: String = "", odometerKm: Double = 0) {
        self.name = name
        self.plate = plate
        self.odometerKm = odometerKm
        self.odometerUpdatedAt = .now
    }
}

enum DataStore {
    static let models: [any PersistentModel.Type] = [Shift.self, Earning.self, Expense.self, Reminder.self, Car.self]

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
}
