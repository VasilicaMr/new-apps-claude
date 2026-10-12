import Foundation

/// Something the driver typed or said, like "fuel 250 lei 34 L at OMV" or "uber 420 tips 30".
enum QuickEntry: Sendable, Equatable {
    case expense(ExpenseDraft)
    case earning(EarningDraft)
}

struct ExpenseDraft: Sendable, Equatable {
    var category: ExpenseCategory
    var amount: Double
    var liters: Double?
    var odometerKm: Double?
    var note: String = ""
    var daysAgo: Int = 0
}

struct EarningDraft: Sendable, Equatable {
    var platform: Platform
    var fares: Double
    var tips: Double = 0
    var bonus: Double = 0
    var trips: Int = 0
    var daysAgo: Int = 0

    var total: Double { fares + tips + bonus }
}

/// Understands short entries in English and Romanian without Apple Intelligence.
/// Apple Intelligence handles free-form sentences; this covers the common shorthand on every iPhone.
struct QuickEntryParser: Sendable {
    private static let categoryWords: [(ExpenseCategory, [String])] = [
        (.fuel, ["fuel", "gas", "petrol", "diesel", "benzina", "motorina", "plin", "alimentat", "carburant",
                 "omv", "petrom", "mol", "lukoil", "rompetrol", "socar", "gazprom"]),
        (.charging, ["charge", "charging", "incarcare", "kwh"]),
        (.carWash, ["wash", "carwash", "spalat", "spalatorie", "spalare"]),
        (.maintenance, ["service", "revizie", "oil", "ulei", "filtre", "filter"]),
        (.repair, ["repair", "reparatie", "mecanic", "garage", "garaj"]),
        (.tyres, ["tyre", "tyres", "tire", "tires", "anvelope", "cauciucuri", "vulcanizare"]),
        (.insurance, ["insurance", "rca", "casco", "asigurare"]),
        (.roadTax, ["rovinieta", "vignette", "impozit", "roadtax"]),
        (.leasing, ["leasing", "rent", "chirie", "rata"]),
        (.parking, ["parking", "parcare"]),
        (.tolls, ["toll", "tolls", "peaj", "pod"]),
        (.fines, ["fine", "amenda", "ticket"]),
        (.phone, ["phone", "telefon", "abonament", "internet"]),
    ]

    private static let stationBrands = ["omv", "petrom", "mol", "lukoil", "rompetrol", "socar", "gazprom"]

    func parse(_ text: String) -> QuickEntry? {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let words = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let wordSet = Set(words)
        let daysAgo = wordSet.contains("yesterday") || wordSet.contains("ieri") ? 1 : 0

        if let platform = platform(in: wordSet) {
            return earning(platform: platform, folded: folded, daysAgo: daysAgo)
        }
        guard let category = Self.categoryWords.first(where: { !wordSet.isDisjoint(with: $0.1) })?.0 else { return nil }
        let numbers = numbersWithUnits(in: folded)
        guard let amount = numbers.first(where: { $0.unit == nil || $0.unit == .money })?.value, amount > 0 else { return nil }
        let brand = Self.stationBrands.first { wordSet.contains($0) }
        return .expense(ExpenseDraft(
            category: category, amount: amount,
            liters: numbers.first { $0.unit == .liters || $0.unit == .kwh }?.value,
            odometerKm: numbers.first { $0.unit == .km }.flatMap { $0.value > 1000 ? $0.value : nil },
            note: brand.map { $0.uppercased() == "MOL" ? "MOL" : $0.capitalized } ?? "",
            daysAgo: daysAgo))
    }

    private func platform(in words: Set<String>) -> Platform? {
        if words.contains("uber") { return .uber }
        if words.contains("bolt") { return .bolt }
        if words.contains("freenow") { return .freeNow }
        return nil
    }

    private func earning(platform: Platform, folded: String, daysAgo: Int) -> QuickEntry? {
        // "tips 30" / "30 tips", "bonus 50", "18 trips" / "18 curse"; the remaining amount is fares.
        func tagged(_ keys: [String]) -> Double? {
            let alternatives = keys.joined(separator: "|")
            if let match = folded.firstMatch(of: try! Regex("(?:\(alternatives))\\s*:?\\s*(\\d+(?:[.,]\\d{1,2})?)")),
               let value = match.output[1].substring.flatMap({ EarningsTextParser().amount(in: String($0)) }) {
                return value
            }
            if let match = folded.firstMatch(of: try! Regex("(\\d+(?:[.,]\\d{1,2})?)\\s*(?:lei|ron)?\\s*(?:\(alternatives))")),
               let value = match.output[1].substring.flatMap({ EarningsTextParser().amount(in: String($0)) }) {
                return value
            }
            return nil
        }
        let tips = tagged(["tips", "tip", "bacsis", "bacsisuri"]) ?? 0
        let bonus = tagged(["bonus", "promo", "promotii", "promotions", "promotion"]) ?? 0
        let trips = tagged(["trips", "curse", "rides"]).map { Int($0) } ?? 0

        var remaining = numbersWithUnits(in: folded).filter { $0.unit == nil || $0.unit == .money }.map(\.value)
        for used in [tips, bonus, Double(trips)] where used > 0 {
            if let index = remaining.firstIndex(of: used) { remaining.remove(at: index) }
        }
        guard let fares = remaining.first, fares > 0 else { return nil }
        return .earning(EarningDraft(platform: platform, fares: fares, tips: tips, bonus: bonus, trips: trips, daysAgo: daysAgo))
    }

    private enum Unit { case money, liters, kwh, km }

    private func numbersWithUnits(in folded: String) -> [(value: Double, unit: Unit?)] {
        folded.matches(of: #/(\d+(?:[.,]\d{1,3})?)\s*(lei|ron|eur|€|l|litri|liters|litres|kwh|km)?\b/#).compactMap { match in
            guard let value = EarningsTextParser().amount(in: String(match.output.1)) else { return nil }
            let unit: Unit? = switch match.output.2.map(String.init) {
            case "lei", "ron", "eur", "€": .money
            case "l", "litri", "liters", "litres": .liters
            case "kwh": .kwh
            case "km": .km
            default: nil
            }
            return (value, unit)
        }
    }
}
