import Foundation

/// Where the money came from. Most drivers work for more than one app.
enum Platform: String, Codable, Sendable, CaseIterable, Identifiable {
    case uber, bolt, freeNow, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uber: "Uber"
        case .bolt: "Bolt"
        case .freeNow: "FREENOW"
        case .other: String(localized: "Other")
        }
    }
}

enum ExpenseCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case fuel, charging, carWash, maintenance, repair, tyres, insurance, roadTax, leasing, parking, tolls, fines, phone, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuel: String(localized: "Fuel")
        case .charging: String(localized: "Charging")
        case .carWash: String(localized: "Car wash")
        case .maintenance: String(localized: "Service")
        case .repair: String(localized: "Repair")
        case .tyres: String(localized: "Tyres")
        case .insurance: String(localized: "Insurance")
        case .roadTax: String(localized: "Road tax / vignette")
        case .leasing: String(localized: "Leasing / rent")
        case .parking: String(localized: "Parking")
        case .tolls: String(localized: "Tolls")
        case .fines: String(localized: "Fines")
        case .phone: String(localized: "Phone & data")
        case .other: String(localized: "Other")
        }
    }

    var symbol: String {
        switch self {
        case .fuel: "fuelpump.fill"
        case .charging: "bolt.car.fill"
        case .carWash: "drop.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        case .repair: "hammer.fill"
        case .tyres: "circle.circle.fill"
        case .insurance: "shield.fill"
        case .roadTax: "road.lanes"
        case .leasing: "doc.text.fill"
        case .parking: "parkingsign"
        case .tolls: "road.lanes.curved.right"
        case .fines: "exclamationmark.octagon.fill"
        case .phone: "iphone"
        case .other: "ellipsis.circle.fill"
        }
    }

    /// Months a payment usually covers. Stats spread it over that time so a yearly
    /// insurance payment doesn't make one day look like a disaster.
    var defaultCoverageMonths: Int {
        switch self {
        case .insurance, .roadTax: 12
        default: 0
        }
    }
}

enum ReminderKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case inspection, liabilityInsurance, comprehensiveInsurance, vignette, carTax
    case oilChange, tyreChange, driverLicence, rideSharePermit, safetyKit, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inspection: String(localized: "Inspection (ITP)")
        case .liabilityInsurance: String(localized: "Liability insurance (RCA)")
        case .comprehensiveInsurance: String(localized: "Comprehensive insurance (CASCO)")
        case .vignette: String(localized: "Road vignette (rovinietă)")
        case .carTax: String(localized: "Car tax")
        case .oilChange: String(localized: "Oil change")
        case .tyreChange: String(localized: "Tyre change")
        case .driverLicence: String(localized: "Driving licence")
        case .rideSharePermit: String(localized: "Ride-sharing permit")
        case .safetyKit: String(localized: "First aid kit / extinguisher")
        case .other: String(localized: "Other")
        }
    }

    var symbol: String {
        switch self {
        case .inspection: "checkmark.seal.fill"
        case .liabilityInsurance, .comprehensiveInsurance: "shield.fill"
        case .vignette: "road.lanes"
        case .carTax: "building.columns.fill"
        case .oilChange: "drop.halffull"
        case .tyreChange: "circle.circle.fill"
        case .driverLicence: "person.text.rectangle.fill"
        case .rideSharePermit: "doc.badge.clock.fill"
        case .safetyKit: "cross.case.fill"
        case .other: "bell.fill"
        }
    }

    /// Sensible defaults; the driver can change them (e.g. ITP every 6 months for ride-sharing cars).
    var defaultRepeatMonths: Int? {
        switch self {
        case .inspection, .liabilityInsurance, .comprehensiveInsurance, .vignette, .carTax, .safetyKit: 12
        case .tyreChange: 6
        case .oilChange, .driverLicence, .rideSharePermit, .other: nil
        }
    }

    var defaultRepeatKm: Double? { self == .oilChange ? 15_000 : nil }

    var usesKilometers: Bool { self == .oilChange }
}
