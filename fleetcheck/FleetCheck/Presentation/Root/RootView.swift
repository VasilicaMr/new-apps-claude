import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(ShiftStore.self) private var shiftStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.hasSeenTutorial) private var hasSeenTutorial = false
    @AppStorage(SettingsKeys.currencyCode) private var currencyCode = MoneyFormatter.defaultCurrencyCode
    @State private var selectedTab = AppTab.launchDefault
    @Query private var reminders: [Reminder]
    @Query private var cars: [Car]

    var body: some View {
        @Bindable var shiftStore = shiftStore
        TabView(selection: $selectedTab) {
            Tab("Shift", systemImage: "steeringwheel", value: .shift) {
                ShiftView()
            }
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
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .environment(\.money, MoneyFormatter(currencyCode: currencyCode))
        .sheet(item: $shiftStore.shiftAwaitingEarnings) { shift in
            EarningForm(shift: shift)
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

enum AppTab: String, Hashable {
    case shift, stats, diary, car, settings

    /// Debug builds accept `-initialTab <name>` so screenshots and UI tests can open any tab directly.
    static var launchDefault: AppTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = AppTab(rawValue: raw) { return tab }
        #endif
        return .shift
    }
}
