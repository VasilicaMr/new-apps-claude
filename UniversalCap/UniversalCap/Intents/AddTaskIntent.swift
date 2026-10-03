import AppIntents
import SwiftData
import Foundation

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a Task"
    static var description = IntentDescription("Add a task or reminder without opening the app.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var title: String

    @Parameter(title: "Due Date")
    var dueDate: Date?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try DataStore.makeContainer()
        let context = ModelContext(container)
        let task = UCTask(title: title, dueDate: dueDate)
        context.insert(task)
        try context.save()
        NotificationScheduler.schedule(for: task)
        if let date = dueDate {
            return .result(dialog: "Task added: \(title), due \(date.formatted(date: .abbreviated, time: .omitted)).")
        }
        return .result(dialog: "Task added: \(title).")
    }
}
