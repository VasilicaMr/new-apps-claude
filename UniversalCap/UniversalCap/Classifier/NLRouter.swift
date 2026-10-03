import NaturalLanguage
import Foundation

// Result of routing a free-text utterance to the correct capture category.
enum CaptureRoute {
    case thought(content: String)
    case expense(amount: Double, currency: String, category: String, note: String)
    case task(title: String, dueDate: Date?)
}

enum NLRouter {

    // Entry point — call this from any intent with raw user text.
    static func route(_ utterance: String) -> CaptureRoute {
        if let expense = tryExpense(utterance) { return expense }
        if let task = tryTask(utterance) { return task }
        return .thought(content: utterance)
    }

    // MARK: - Expense

    private static let expenseVerbs = [
        "spent", "paid", "bought", "cost", "charged", "owe", "purchased", "bill"
    ]

    private static let categoryMap: [(category: String, keywords: [String])] = [
        ("Food",          ["lunch", "dinner", "breakfast", "coffee", "tea", "restaurant",
                           "cafe", "food", "meal", "eat", "drink", "bar", "snack", "pizza"]),
        ("Transport",     ["taxi", "uber", "lyft", "bus", "metro", "train", "fuel",
                           "gas", "parking", "ride", "flight", "ticket", "transport"]),
        ("Health",        ["pharmacy", "doctor", "medicine", "gym", "health",
                           "medical", "dentist", "prescription", "clinic"]),
        ("Shopping",      ["clothes", "shirt", "shoes", "shopping", "store",
                           "amazon", "online", "order", "delivery"]),
        ("Entertainment", ["movie", "cinema", "concert", "game", "spotify",
                           "netflix", "subscription", "streaming"]),
    ]

    private static func tryExpense(_ text: String) -> CaptureRoute? {
        guard let amount = extractAmount(from: text) else { return nil }

        let lower = text.lowercased()
        let hasCurrencySymbol = text.contains("€") || text.contains("$")
                             || text.contains("£") || text.contains("¥")
        let hasVerb = expenseVerbs.contains { lower.contains($0) }
        guard hasCurrencySymbol || hasVerb else { return nil }

        let currency = detectCurrency(in: text)
        let category = detectExpenseCategory(in: lower)
        return .expense(amount: amount, currency: currency, category: category, note: text)
    }

    // Matches: €12  $5.50  £ 8  12.99  12,50
    private static let amountRegex = try! NSRegularExpression(
        pattern: #"[€$£¥]?\s*(\d{1,6}(?:[.,]\d{1,2})?)"#
    )

    private static func extractAmount(from text: String) -> Double? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = amountRegex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        let raw = text[captureRange].replacingOccurrences(of: ",", with: ".")
        return Double(raw)
    }

    private static func detectCurrency(in text: String) -> String {
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("¥") { return "JPY" }
        return "USD"
    }

    private static func detectExpenseCategory(in lower: String) -> String {
        for entry in categoryMap {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return entry.category
            }
        }
        return "Other"
    }

    // MARK: - Task

    private static let taskSignals = [
        "need to", "have to", "must", "should", "don't forget", "do not forget",
        "remind me", "remember to", "todo", "to-do", "call", "email", "send",
        "book", "schedule", "pick up", "follow up", "check on", "reply to"
    ]

    private static let titlePrefixes = [
        "remind me to ", "remind me ", "i need to ", "i have to ",
        "don't forget to ", "don't forget ", "do not forget to ",
        "remember to ", "todo: ", "to-do: ", "to do: "
    ]

    private static func tryTask(_ text: String) -> CaptureRoute? {
        let lower = text.lowercased()
        let hasSignal = taskSignals.contains { lower.contains($0) }
        let dueDate = extractDate(from: text)

        // Require either a task keyword or a future date reference
        guard hasSignal || (dueDate != nil && isFuture(dueDate!)) else { return nil }

        let title = cleanTitle(text)
        return .task(title: title, dueDate: dueDate)
    }

    // NSDataDetector handles "tomorrow", "next Monday", "at 3pm", "in two hours", etc.
    private static let dateDetector = try! NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    private static func extractDate(from text: String) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        return dateDetector.matches(in: text, range: range).first?.date
    }

    private static func isFuture(_ date: Date) -> Bool {
        date > Calendar.current.startOfDay(for: Date())
    }

    private static func cleanTitle(_ text: String) -> String {
        var result = text
        let lower = text.lowercased()
        for prefix in titlePrefixes {
            if lower.hasPrefix(prefix) {
                result = String(text.dropFirst(prefix.count))
                break
            }
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}
