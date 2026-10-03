import SwiftUI
import SwiftData
import AppIntents

@main
struct UniversalCapApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("installDate") private var installDate: Double = Date().timeIntervalSince1970

    let container: ModelContainer
    private let isScreenshotMode   = CommandLine.arguments.contains("--screenshot-mode")
    private let isOnboardingMode   = CommandLine.arguments.contains("--show-onboarding")

    init() {
        // Use in-memory for any UI-test launch flag — CloudKit is unavailable in the simulator
        let useInMemory = CommandLine.arguments.contains("--screenshot-mode")
                       || CommandLine.arguments.contains("--show-onboarding")
        do {
            if useInMemory {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(
                    for: Thought.self, Expense.self, UCTask.self,
                    configurations: config
                )
                if CommandLine.arguments.contains("--screenshot-mode") {
                    DemoDataSeeder.seed(into: container.mainContext)
                }
            } else {
                let config = ModelConfiguration(cloudKitDatabase: .automatic)
                container = try ModelContainer(
                    for: Thought.self, Expense.self, UCTask.self,
                    configurations: config
                )
            }
        } catch {
            fatalError("Container failed: \(error)")
        }
        if installDate == 0 { installDate = Date().timeIntervalSince1970 }
        _ = StoreKitManager.shared
        NotificationScheduler.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            if isOnboardingMode {
                OnboardingView()
            } else if isScreenshotMode || hasCompletedOnboarding {
                HomeView()
                    .onAppear {
                        UniversalCapShortcuts.updateAppShortcutParameters()
                    }
            } else {
                OnboardingView()
            }
        }
        .modelContainer(container)
    }
}
