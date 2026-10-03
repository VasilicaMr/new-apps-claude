import AppIntents

struct UniversalCapShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        // Universal — the primary entry point. One phrase, AI routes it.
        AppShortcut(
            intent: UniversalCaptureIntent(),
            phrases: [
                "Capture with \(.applicationName)",
                "Record with \(.applicationName)"
            ],
            shortTitle: "Capture",
            systemImageName: "waveform.circle"
        )
        // Explicit fallbacks for when the user wants to be specific.
        AppShortcut(
            intent: CaptureThoughtIntent(),
            phrases: [
                "Capture a thought with \(.applicationName)",
                "Note an idea with \(.applicationName)"
            ],
            shortTitle: "Thought",
            systemImageName: "lightbulb"
        )
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense with \(.applicationName)",
                "Track spending with \(.applicationName)"
            ],
            shortTitle: "Expense",
            systemImageName: "dollarsign.circle"
        )
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task with \(.applicationName)",
                "Remind me with \(.applicationName)"
            ],
            shortTitle: "Task",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: TodaySpendIntent(),
            phrases: [
                "What did I spend today with \(.applicationName)",
                "How much have I spent with \(.applicationName)",
                "Show my spending in \(.applicationName)"
            ],
            shortTitle: "Today's Spend",
            systemImageName: "dollarsign.circle.fill"
        )
        AppShortcut(
            intent: OpenTasksIntent(),
            phrases: [
                "What are my open tasks in \(.applicationName)",
                "Show my tasks in \(.applicationName)",
                "What do I need to do in \(.applicationName)"
            ],
            shortTitle: "Open Tasks",
            systemImageName: "checklist"
        )
    }
}
