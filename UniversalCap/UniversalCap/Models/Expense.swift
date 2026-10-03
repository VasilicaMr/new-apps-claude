import SwiftData
import Foundation

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Double = 0.0
    var currency: String = "EUR"
    var category: String = "Other"
    var note: String = ""
    var createdAt: Date = Date()

    init(amount: Double, currency: String = "EUR", category: String = "Other", note: String = "") {
        self.id = UUID()
        self.amount = amount
        self.currency = currency
        self.category = category
        self.note = note
        self.createdAt = Date()
    }
}
