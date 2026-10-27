import Foundation

/// Builds spreadsheet-friendly CSV (RFC 4180) for the driver's accountant or their own records.
/// Numbers use a dot decimal separator and dates ISO 8601, so any spreadsheet app can parse them.
struct CSVExporter: Sendable {
    struct ShiftRow: Sendable {
        let start: Date
        let end: Date?
        let distanceKm: Double
        let earnings: Double
        let note: String
    }

    struct EarningRow: Sendable {
        let date: Date
        let platform: Platform
        let fares: Double
        let tips: Double
        let bonus: Double
        let trips: Int
        var distanceKm: Double = 0
        var destination: String = ""
        var cash: Double = 0
        let note: String
    }

    struct ExpenseRow: Sendable {
        let date: Date
        let category: ExpenseCategory
        let amount: Double
        let liters: Double?
        let odometerKm: Double?
        let note: String
    }

    var timeZone: TimeZone = .current

    func shifts(_ rows: [ShiftRow]) -> String {
        table(header: ["start", "end", "hours", "km", "earnings", "note"], rows: rows.map { row in
            [date(row.start), row.end.map(date) ?? "",
             row.end.map { number($0.timeIntervalSince(row.start) / 3600) } ?? "",
             number(row.distanceKm), number(row.earnings), row.note]
        })
    }

    func earnings(_ rows: [EarningRow]) -> String {
        table(header: ["date", "platform", "fares", "tips", "bonus", "total", "trips", "cash", "km", "destination", "note"], rows: rows.map {
            [date($0.date), $0.platform.title, number($0.fares), number($0.tips), number($0.bonus),
             number($0.fares + $0.tips + $0.bonus), String($0.trips), number($0.cash), number($0.distanceKm), $0.destination, $0.note]
        })
    }

    func expenses(_ rows: [ExpenseRow]) -> String {
        table(header: ["date", "category", "amount", "liters", "odometer_km", "note"], rows: rows.map {
            [date($0.date), $0.category.title, number($0.amount), $0.liters.map(number) ?? "",
             $0.odometerKm.map(number) ?? "", $0.note]
        })
    }

    func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func table(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    private func number(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func date(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: value)
    }
}
