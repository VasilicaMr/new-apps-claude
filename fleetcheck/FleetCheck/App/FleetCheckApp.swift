import AppIntents
import SwiftData
import SwiftUI

@main
struct FleetCheckApp: App {
    private let container: ModelContainer
    @State private var shiftStore: ShiftStore

    init() {
        let container = DataStore.makeContainer()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            SampleData.reset(container.mainContext)
        }
        #endif
        let store = ShiftStore(context: container.mainContext)
        self.container = container
        _shiftStore = State(initialValue: store)

        // Siri, Shortcuts and the Live Activity button reach the same store as the UI.
        AppDependencyManager.shared.add { store }
        AppDependencyManager.shared.add { container }
        ShiftControl.endShift = { store.endShiftSummary() }
        store.resumeIfNeeded()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-startShift") { store.startShift() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(shiftStore)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}

enum SettingsKeys {
    static let hasSeenTutorial = "hasSeenTutorial"
    static let currencyCode = "currencyCode"
    static let useAppleIntelligence = "useAppleIntelligence"
}

extension ModelContext {
    /// Rebuilds reminder notifications after any reminder changes.
    func rescheduleReminderNotifications() {
        let items = ((try? fetch(FetchDescriptor<Reminder>())) ?? []).compactMap { reminder in
            reminder.dueDate.map { ReminderNotifier.Item(id: reminder.id, title: reminder.title, dueDate: $0) }
        }
        Task { await ReminderNotifier.reschedule(items) }
    }
}
