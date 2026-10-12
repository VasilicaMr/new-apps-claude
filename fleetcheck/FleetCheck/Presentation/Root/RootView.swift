import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(ShiftStore.self) private var shiftStore
    @Environment(AppNavigation.self) private var navigation
    @Environment(ScreenshotInbox.self) private var inbox
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.hasSeenTutorial) private var hasSeenTutorial = false
    @AppStorage(SettingsKeys.currencyCode) private var currencyCode = MoneyFormatter.defaultCurrencyCode
    @Query private var reminders: [Reminder]
    @Query private var cars: [Car]

    let data: DriverData

    var body: some View {
        @Bindable var shiftStore = shiftStore
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                HomeView(data: data)
            }
            .badge(inbox.items.count)
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                StatsView()
            }
            Tab("Diary", systemImage: "list.bullet.rectangle", value: .diary) {
                DiaryView()
            }
            Tab("Car", systemImage: "car.fill", value: .car) {
                CarView()
            }
            .badge(dueCount)
            Tab("Ask", systemImage: "sparkles", value: .ask, role: .search) {
                AssistantView()
            }
        }
        .environment(\.money, MoneyFormatter(currencyCode: currencyCode))
        .sheet(item: $shiftStore.shiftAwaitingEarnings) { shift in
            // Ending a shift goes straight to reading the earnings screenshot.
            EarningForm(shift: shift, scanScreenshot: true)
                .environment(\.money, MoneyFormatter(currencyCode: currencyCode))
        }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenTutorial }, set: { hasSeenTutorial = !$0 })) {
            TutorialView { hasSeenTutorial = true }
        }
        #if DEBUG
        .sheet(isPresented: .constant(UserDefaults.standard.string(forKey: "debugScanImage") != nil)) {
            EarningForm(shift: nil).environment(\.money, MoneyFormatter(currencyCode: currencyCode))
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { shiftStore.resumeIfNeeded() }
        }
    }

    private var dueCount: Int {
        let odometer = cars.first?.odometerKm ?? 0
        let planner = ReminderPlanner()
        return reminders.filter { planner.status(of: $0.rule, today: .now, odometerKm: odometer).urgency > .ok }.count
    }
}
