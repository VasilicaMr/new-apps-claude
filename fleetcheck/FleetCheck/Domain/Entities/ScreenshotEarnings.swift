import Foundation

/// Earnings read from a screenshot of a ride-sharing app's earnings screen.
/// Every field is optional: the screen may not show it, or reading may have missed it.
struct ScreenshotEarnings: Sendable, Equatable {
    enum Scope: String, Sendable {
        case trip, day, week, unknown
    }

    enum Source: Sendable, Equatable {
        /// On-device Apple Intelligence (Foundation Models) understood the text.
        case appleIntelligence
        /// Keyword matching, used when Apple Intelligence isn't available on this iPhone.
        case textMatching
    }

    var platform: Platform?
    var scope: Scope = .unknown
    var date: Date?
    var total: Double?
    var fares: Double?
    var tips: Double?
    var bonus: Double?
    var trips: Int?
    /// Kilometers driven: the trip's distance, or the day's/week's total.
    var distanceKm: Double?
    /// Drop-off address of a single trip.
    var destination: String?
    /// Cash the passengers paid in the car. Part of the earnings (not extra); the app pays out the rest.
    var cashCollected: Double?
    var source: Source = .textMatching
    /// The rows of text read from the image, kept for "this was read wrong" reports.
    var recognizedLines: [String] = []

    /// One line for reports: "app=Bolt scope=week total=1874.30 fares=1702.80 tips=41.50 bonus=130.00 trips=64 km=412.5".
    var summary: String {
        let money = { (value: Double?) in value.map { String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "-" }
        return "app=\(platform?.title ?? "-") scope=\(scope.rawValue) total=\(money(total)) fares=\(money(fares)) "
            + "tips=\(money(tips)) bonus=\(money(bonus)) trips=\(trips.map(String.init) ?? "-")"
            + (distanceKm.map { " km=\(money($0))" } ?? "") + (cashCollected.map { " cash=\(money($0))" } ?? "")
            + (destination.map { " to=\($0)" } ?? "")
    }

    var isEmpty: Bool { total == nil && fares == nil && tips == nil && bonus == nil }

    /// Makes the parts agree with the headline total the app shows.
    ///
    /// The total is the most reliable number on these screens (biggest, clearest), so when
    /// fares + tips + bonus don't add up to it, fares is recomputed as the remainder.
    func normalized() -> ScreenshotEarnings {
        var result = self
        let tips = max(0, tips ?? 0)
        let bonus = max(0, bonus ?? 0)
        result.tips = self.tips.map { max(0, $0) }
        result.bonus = self.bonus.map { max(0, $0) }

        if let total, total > 0 {
            let partsSum = (fares ?? 0) + tips + bonus
            if fares == nil || abs(partsSum - total) > 0.5 {
                let remainder = total - tips - bonus
                if remainder >= 0 {
                    result.fares = (remainder * 100).rounded() / 100
                } else {
                    // Tips/bonus misread as bigger than the total: trust the total alone.
                    result.fares = total
                    result.tips = nil
                    result.bonus = nil
                }
            }
        } else if let fares {
            result.total = fares + tips + bonus
        }
        if let trips = result.trips, trips < 0 || trips > 500 { result.trips = nil }
        if let km = result.distanceKm, km <= 0 || km > 10_000 { result.distanceKm = nil }
        if let cash = result.cashCollected {
            // Shown as "-145,00" on some screens because it's deducted from the payout.
            result.cashCollected = abs(cash) > 0 ? abs(cash) : nil
        }
        if let destination = result.destination?.trimmingCharacters(in: .whitespaces) {
            result.destination = destination.isEmpty ? nil : destination
        }
        return result
    }
}
