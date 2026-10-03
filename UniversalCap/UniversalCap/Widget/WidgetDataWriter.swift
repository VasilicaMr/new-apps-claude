import Foundation
import WidgetKit

// Shared snapshot written by the app, read by the widget extension.
// Both targets must belong to the same App Group: group.com.universalcap
struct WidgetSnapshot: Codable {
    var thoughtCount: Int
    var expenseCount: Int
    var taskTotalCount: Int
    var taskOpenCount: Int
    var totalSpentToday: Double
    var currency: String
    var latestCapture: String

    var totalCaptures: Int { thoughtCount + expenseCount + taskTotalCount }
}

enum WidgetDataWriter {
    private static let suiteName = "group.com.universalcap"
    private static let key = "widgetSnapshot"

    static func write(thoughts: [Thought], expenses: [Expense], tasks: [UCTask]) {
        let cal = Calendar.current
        let todayTotal = expenses
            .filter { cal.isDateInToday($0.createdAt) }
            .reduce(0.0) { $0 + $1.amount }

        let currency = expenses.first?.currency ?? "EUR"

        // Pick the most recent item across all three types
        let candidates: [(Date, String)] =
            thoughts.prefix(1).map { ($0.createdAt, $0.content) } +
            expenses.prefix(1).map { ($0.createdAt, "\($0.currency) \(String(format: "%.0f", $0.amount)) – \($0.category)") } +
            tasks.prefix(1).map { ($0.createdAt, $0.title) }

        let latest = candidates.max(by: { $0.0 < $1.0 })?.1 ?? ""

        let snapshot = WidgetSnapshot(
            thoughtCount: thoughts.count,
            expenseCount: expenses.count,
            taskTotalCount: tasks.count,
            taskOpenCount: tasks.filter { !$0.isCompleted }.count,
            totalSpentToday: todayTotal,
            currency: currency,
            latestCapture: latest
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
