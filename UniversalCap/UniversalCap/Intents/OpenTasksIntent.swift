import AppIntents
import SwiftData
import Foundation

struct OpenTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tasks"
    static var description = IntentDescription("Ask how many open tasks you have and what's due next.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try DataStore.makeContainer()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<UCTask>(
            predicate: #Predicate { $0.isCompleted == false }
        )
        let open = try context.fetch(descriptor)

        guard !open.isEmpty else {
            return .result(dialog: "No open tasks. You're all caught up!")
        }

        let count = open.count
        let now = Date()

        // Overdue tasks (due date in the past)
        let overdue = open.filter { $0.dueDate != nil && $0.dueDate! < now }

        // Next upcoming due task
        let upcoming = open
            .filter { $0.dueDate != nil && $0.dueDate! >= now }
            .sorted { $0.dueDate! < $1.dueDate! }

        if !overdue.isEmpty {
            let overdueNote = overdue.count == 1
                ? "1 is overdue: \(overdue[0].title)."
                : "\(overdue.count) are overdue."

            if let next = upcoming.first, let due = next.dueDate {
                return .result(dialog: IntentDialog(stringLiteral:
                    "You have \(count) open \(count == 1 ? "task" : "tasks"). \(overdueNote) Next up: \(next.title), due \(due.formatted(date: .abbreviated, time: .omitted))."
                ))
            }
            return .result(dialog: IntentDialog(stringLiteral:
                "You have \(count) open \(count == 1 ? "task" : "tasks"). \(overdueNote)"
            ))
        }

        if let next = upcoming.first, let due = next.dueDate {
            return .result(dialog: IntentDialog(stringLiteral:
                "You have \(count) open \(count == 1 ? "task" : "tasks"). Next due: \(next.title), \(due.formatted(date: .abbreviated, time: .omitted))."
            ))
        }

        // No due dates on any task — just report the first one
        return .result(dialog: IntentDialog(stringLiteral:
            "You have \(count) open \(count == 1 ? "task" : "tasks"). First up: \(open[0].title)."
        ))
    }
}
