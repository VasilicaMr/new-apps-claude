import SwiftData
import Foundation

enum DemoDataSeeder {
    static func seed(into context: ModelContext) {
        let now = Date()
        let cal = Calendar.current

        // Thoughts
        let thoughts: [(String, Date)] = [
            ("What if we used a freemium model instead of subscriptions? Lower barrier to entry, upsell later.",
             cal.date(byAdding: .hour, value: -2, to: now)!),
            ("Idea: add a weekly digest email that summarises all captures — thoughts, spend, completed tasks.",
             cal.date(byAdding: .day, value: -1, to: now)!),
            ("The onboarding gradient animations feel premium. Keep the same palette in the widget.",
             cal.date(byAdding: .day, value: -2, to: now)!),
        ]
        for (content, date) in thoughts {
            let t = Thought(content: content)
            t.createdAt = date
            context.insert(t)
        }

        // Expenses
        let expenses: [(Double, String, String, String, Date)] = [
            (12.50, "EUR", "Food",        "Lunch at the Italian place near the office",
             cal.date(byAdding: .hour, value: -4, to: now)!),
            (3.80,  "EUR", "Food",        "Morning coffee",
             cal.date(byAdding: .hour, value: -6, to: now)!),
            (49.99, "EUR", "Shopping",    "New keyboard wrist rest",
             cal.date(byAdding: .day, value: -1, to: now)!),
            (28.00, "EUR", "Transport",   "Taxi to airport",
             cal.date(byAdding: .day, value: -2, to: now)!),
            (9.99,  "USD", "Entertainment","Spotify subscription",
             cal.date(byAdding: .day, value: -3, to: now)!),
        ]
        for (amount, currency, category, note, date) in expenses {
            let e = Expense(amount: amount, currency: currency, category: category, note: note)
            e.createdAt = date
            context.insert(e)
        }

        // Tasks
        let tasks: [(String, Date?, Bool, Date)] = [
            ("Call Ana about the contract renewal",
             cal.date(byAdding: .day, value: 1, to: now), false,
             cal.date(byAdding: .hour, value: -1, to: now)!),
            ("Book dentist appointment",
             cal.date(byAdding: .day, value: 3, to: now), false,
             cal.date(byAdding: .day, value: -1, to: now)!),
            ("Review pull request from Miguel",
             nil, false,
             cal.date(byAdding: .day, value: -1, to: now)!),
            ("Send invoice to client",
             cal.date(byAdding: .day, value: -1, to: now), false,
             cal.date(byAdding: .day, value: -2, to: now)!),
            ("Pick up dry cleaning",
             nil, true,
             cal.date(byAdding: .day, value: -2, to: now)!),
        ]
        for (title, due, completed, created) in tasks {
            let task = UCTask(title: title, dueDate: due)
            task.isCompleted = completed
            task.createdAt = created
            context.insert(task)
        }

        try? context.save()
    }
}
