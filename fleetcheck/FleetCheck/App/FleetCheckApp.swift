import AppIntents
import SwiftData
import SwiftUI

@main
struct FleetCheckApp: App {
    private let container: ModelContainer
    @State private var shiftStore: ShiftStore
    @State private var assistant: Assistant
    @State private var navigation = AppNavigation()
    @State private var brief = BriefStore()
    @State private var inbox = ScreenshotInbox()
    @State private var pro = ProStore()
    private let data: DriverData

    init() {
        let container = DataStore.makeContainer()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            SampleData.reset(container.mainContext)
        }
        #endif
        let store = ShiftStore(context: container.mainContext)
        let data = DriverData(context: container.mainContext)
        let assistant = Assistant(data: data)
        self.container = container
        self.data = data
        _shiftStore = State(initialValue: store)
        _assistant = State(initialValue: assistant)

        // Siri, Shortcuts and the Live Activity button reach the same objects as the UI.
        AppDependencyManager.shared.add { store }
        AppDependencyManager.shared.add { container }
        AppDependencyManager.shared.add { assistant }
        ShiftControl.endShift = { await store.endShiftSummary() }
        store.resumeIfNeeded()
        Theme.applyAppearance()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-startShift") { store.startShift() }
        // `-askQuestion "…"` opens Ask and sends the question, for testing the assistant.
        if let question = UserDefaults.standard.string(forKey: "askQuestion") { navigation.ask(question) }
        // `-inboxImages "/a.png,/b.png"` puts images in the Home inbox as if found in Photos (simulator testing).
        if let paths = UserDefaults.standard.string(forKey: "inboxImages") {
            let inbox = inbox
            Task { @MainActor in
                for (index, path) in paths.split(separator: ",").enumerated() {
                    guard let image = FileManager.default.contents(atPath: String(path)) else { continue }
                    let takenAt = Calendar.current.date(byAdding: .minute, value: -30 * (index + 1), to: .now) ?? .now
                    await inbox.ingest(image, id: String(path), takenAt: takenAt, data: data, useAppleIntelligence: true)
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(data: data)
                .environment(shiftStore)
                .environment(assistant)
                .environment(navigation)
                .environment(brief)
                .environment(inbox)
                .environment(pro)
                .task { await pro.load() }
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
        .modelContainer(container)
    }
}

enum SettingsKeys {
    static let hasSeenTutorial = "hasSeenTutorial"
    static let currencyCode = "currencyCode"
    static let useAppleIntelligence = "useAppleIntelligence"
    static let autoImportScreenshots = "autoImportScreenshots"
    /// The "How to upload" steps open by themselves the first time only.
    static let hasSeenUploadGuide = "hasSeenUploadGuide"
    static let hideGettingStarted = "hideGettingStarted"
    /// Net amount the driver wants to keep each week; 0 = no goal.
    static let weeklyGoal = "weeklyGoal"
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
