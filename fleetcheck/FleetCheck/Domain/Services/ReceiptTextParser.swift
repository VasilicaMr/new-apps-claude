import Foundation

/// A receipt photo, understood.
struct ScannedReceipt: Sendable, Equatable {
    var category: ExpenseCategory?
    var amount: Double?
    var liters: Double?
    var vendor: String?
    var date: Date?
    var source: ScreenshotEarnings.Source = .textMatching

    var isEmpty: Bool { amount == nil }
}

/// Reads fuel and service receipts (Romanian and English) without Apple Intelligence:
/// the TOTAL line, liters ("34,12 L"), the station brand, and the date.
struct ReceiptTextParser: Sendable {
    private let money = EarningsTextParser()

    private static let brands = ["OMV", "Petrom", "MOL", "Lukoil", "Rompetrol", "Socar", "Gazprom", "Shell", "Kaufland", "Auchan"]

    func parse(lines: [String], calendar: Calendar = .current) -> ScannedReceipt {
        var receipt = ScannedReceipt()
        let folded = lines.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let all = folded.joined(separator: "\n")

        // Total: the last amount on the last line that says TOTAL (not subtotal / TVA lines).
        for (line, foldedLine) in zip(lines, folded).reversed()
        where foldedLine.contains("total") && !foldedLine.contains("subtotal") && !foldedLine.contains("tva") {
            if let value = money.amounts(in: line).last ?? plainAmount(in: line) {
                receipt.amount = value
                break
            }
        }
        if receipt.amount == nil {
            receipt.amount = lines.flatMap { money.amounts(in: $0) }.filter { $0 > 0 }.max()
        }

        if let match = all.firstMatch(of: #/(\d+[.,]\d{1,3})\s*(?:l|litri|ltr|litres|liters)\b/#),
           let liters = money.amount(in: String(match.output.1)), liters > 0, liters < 200 {
            receipt.liters = liters
        }

        receipt.vendor = Self.brands.first { brand in folded.contains { $0.contains(brand.lowercased()) } }
        receipt.category = category(all, hasLiters: receipt.liters != nil, vendor: receipt.vendor)
        receipt.date = date(in: all, calendar: calendar)
        return receipt
    }

    private func category(_ all: String, hasLiters: Bool, vendor: String?) -> ExpenseCategory? {
        if hasLiters || ["benzina", "motorina", "diesel", "petrol", "fuel", "carburant", "efix", "maxx"].contains(where: all.contains) {
            return .fuel
        }
        if ["kwh", "incarcare", "charging"].contains(where: all.contains) { return .charging }
        if ["spalatorie", "spalare", "car wash", "wash"].contains(where: all.contains) { return .carWash }
        if ["parcare", "parking"].contains(where: all.contains) { return .parking }
        if ["revizie", "ulei", "filtru", "service"].contains(where: all.contains) { return .maintenance }
        if ["anvelope", "vulcanizare", "tyre", "tire"].contains(where: all.contains) { return .tyres }
        if ["rovinieta", "vignette"].contains(where: all.contains) { return .roadTax }
        if ["peaj", "toll"].contains(where: all.contains) { return .tolls }
        return vendor.map { ["Kaufland", "Auchan"].contains($0) ? .other : .fuel }
    }

    /// "12.10.2026", "12/10/2026", "2026-10-12".
    private func date(in all: String, calendar: Calendar) -> Date? {
        if let match = all.firstMatch(of: #/\b(\d{1,2})[.\/-](\d{1,2})[.\/-](20\d{2})\b/#),
           let day = Int(match.output.1), let month = Int(match.output.2), let year = Int(match.output.3) {
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
        }
        if let match = all.firstMatch(of: #/\b(20\d{2})-(\d{2})-(\d{2})\b/#),
           let year = Int(match.output.1), let month = Int(match.output.2), let day = Int(match.output.3) {
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
        }
        return nil
    }

    /// Receipts often print "TOTAL 250" with no currency or decimals.
    private func plainAmount(in line: String) -> Double? {
        line.matches(of: #/\d+(?:[.,]\d{1,2})?/#).last.flatMap { money.amount(in: String($0.output)) }
    }
}

/// Finds the shift an entry belongs to: the one running at that moment, or that ended up to
/// `grace` before it (drivers screenshot their earnings right after going offline).
struct ShiftMatcher: Sendable {
    var grace: TimeInterval = 3 * 3600

    func index(for date: Date, in shifts: [(start: Date, end: Date)]) -> Int? {
        shifts.indices
            .filter { shifts[$0].start <= date && date <= shifts[$0].end.addingTimeInterval(grace) }
            .max { shifts[$0].start < shifts[$1].start }
    }
}
