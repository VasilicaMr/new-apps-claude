import AppIntents
import SwiftData

struct UniversalCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Anything"
    static var description = IntentDescription(
        "Say anything — UniversalCap figures out where it goes."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Capture")
    var utterance: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try DataStore.makeContainer()
        let context = ModelContext(container)

        switch NLRouter.route(utterance) {

        case .thought(let content):
            context.insert(Thought(content: content))
            try context.save()
            return .result(dialog: "Thought captured.")

        case .expense(let amount, let currency, let category, let note):
            context.insert(Expense(amount: amount, currency: currency, category: category, note: note))
            try context.save()
            let formatted = String(format: "%.2f", amount)
            return .result(dialog: "Logged \(currency) \(formatted) under \(category).")

        case .task(let title, let dueDate):
            context.insert(UCTask(title: title, dueDate: dueDate))
            try context.save()
            if let date = dueDate {
                let dateStr = date.formatted(date: .abbreviated, time: .omitted)
                return .result(dialog: "Task added: \(title), due \(dateStr).")
            }
            return .result(dialog: "Task added: \(title).")
        }
    }
}
