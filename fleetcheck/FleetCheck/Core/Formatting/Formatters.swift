import Foundation

/// Formatting tied to the company's currency. Created once from `Company.currencyCode`.
struct MoneyFormatter: Sendable {
    let currencyCode: String

    func string(_ amount: Double, compact: Bool = false) -> String {
        if compact, abs(amount) >= 10_000 {
            return amount.formatted(.currency(code: currencyCode).notation(.compactName).precision(.fractionLength(0...1)))
        }
        return amount.formatted(.currency(code: currencyCode).precision(.fractionLength(abs(amount) < 10 ? 2 : 0)))
    }
}

extension Double {
    var kilometers: String { "\(formatted(.number.precision(.fractionLength(0)))) km" }
    var meters: String { "\(formatted(.number.precision(.fractionLength(0)))) m" }
    var percentString: String { formatted(.percent.precision(.fractionLength(0))) }
}
