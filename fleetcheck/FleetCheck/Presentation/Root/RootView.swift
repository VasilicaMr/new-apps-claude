import SwiftUI

struct RootView: View {
    @Environment(FleetStore.self) private var fleetStore
    @Environment(LiveTrackingStore.self) private var liveStore
    @AppStorage(SettingsKeys.hasSeenTutorial) private var hasSeenTutorial = false
    @AppStorage(SettingsKeys.thresholdMeters) private var thresholdMeters = 50.0
    @State private var selectedTab = AppTab.launchDefault

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.67percent", value: .dashboard) {
                DashboardView(selectedTab: $selectedTab)
            }
            Tab("Live", systemImage: "map", value: .live) {
                LiveMapView()
            }
            Tab("Vehicles", systemImage: "car.2", value: .vehicles) {
                VehicleListView()
            }
            Tab("Insights", systemImage: "lightbulb", value: .insights) {
                InsightsView()
            }
            .badge(criticalCount)
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .task {
            liveStore.thresholdMeters = thresholdMeters
            liveStore.start()
            await fleetStore.loadIfNeeded()
        }
        .onChange(of: thresholdMeters) { _, new in liveStore.thresholdMeters = new }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenTutorial }, set: { hasSeenTutorial = !$0 })) {
            TutorialView { hasSeenTutorial = true }
        }
    }

    private var criticalCount: Int {
        fleetStore.insights.filter { $0.severity == .critical }.count
    }
}

enum AppTab: String, Hashable {
    case dashboard, live, vehicles, insights, settings

    /// Debug builds accept `-initialTab <name>` so screenshots and UI tests can open any tab directly.
    static var launchDefault: AppTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = AppTab(rawValue: raw) { return tab }
        #endif
        return .dashboard
    }
}

enum SettingsKeys {
    static let hasSeenTutorial = "hasSeenTutorial"
    static let thresholdMeters = "trackingThresholdMeters"
    static let lowPowerTracking = "lowPowerTracking"
}
