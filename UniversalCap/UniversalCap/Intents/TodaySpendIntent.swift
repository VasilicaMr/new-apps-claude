import AppIntents
import SwiftData
import Foundation

struct TodaySpendIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Spending"
    static var description = IntentDescription("Ask how much you've spent today.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try DataStore.makeContainer()
        let context = ModelContext(container)

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.createdAt >= startOfDay }
        )
        let expenses = try context.fetch(descriptor)

        guard !expenses.isEmpty else {
            return .result(dialog: "Nothing logged today yet. Go treat yourself.")
        }

        let total = expenses.reduce(0.0) { $0 + $1.amount }
        let currency = expenses.first?.currency ?? "EUR"
        let totalStr = formatted(total)
        let count = expenses.count

        // Biggest category by total spend
        let byCategory = Dictionary(grouping: expenses, by: \.category)
            .mapValues { $0.reduce(0.0) { $0 + $1.amount } }

        if let top = byCategory.max(by: { $0.value < $1.value }), byCategory.count > 1 {
            return .result(dialog: IntentDialog(stringLiteral:
                "You've spent \(currency) \(totalStr) today across \(count) \(count == 1 ? "expense" : "expenses"). Most on \(top.key): \(currency) \(formatted(top.value))."
            ))
        }

        return .result(dialog: IntentDialog(stringLiteral:
            "You've spent \(currency) \(totalStr) today across \(count) \(count == 1 ? "expense" : "expenses")."
        ))
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
