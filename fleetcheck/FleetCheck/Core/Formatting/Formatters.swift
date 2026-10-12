import Foundation

enum Formatters {
    /// "2 h 05 min", "45 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let hours = minutes / 60
        return hours > 0 ? String(format: "%d h %02d min", hours, minutes % 60) : "\(minutes) min"
    }

    static func hours(_ hours: Double) -> String {
        "\(hours.formatted(.number.precision(.fractionLength(hours < 10 ? 1 : 0)))) h"
    }
}

/// Money in the driver's currency (Settings → Currency).
struct MoneyFormatter: Sendable {
    let currencyCode: String

    static var defaultCurrencyCode: String { Locale.current.currency?.identifier ?? "RON" }

    func string(_ amount: Double, decimals: Bool = false) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(decimals ? 2 : 0)))
    }
}

extension Double {
    var kilometers: String { "\(formatted(.number.precision(.fractionLength(self < 100 ? 1 : 0)))) km" }
    var percentString: String { formatted(.percent.precision(.fractionLength(0))) }
}
