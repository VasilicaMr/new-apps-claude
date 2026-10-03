import AppIntents
import SwiftData

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Expense"
    static var description = IntentDescription("Quickly log a spend without opening the app.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category", default: "Other")
    var category: String

    @Parameter(title: "Note", default: "")
    var note: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try DataStore.makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: amount, category: category, note: note))
        try context.save()
        return .result(dialog: "Logged \(amount) for \(category).")
    }
}
