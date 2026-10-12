import SwiftUI

@Observable
@MainActor
final class AppCoordinator {
    var selectedTab: AppTab = .home
    var homeCoordinator: HomeCoordinator
    var historyCoordinator: HistoryCoordinator
    var playersCoordinator: PlayersCoordinator

    let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        self.homeCoordinator = HomeCoordinator(container: container)
        self.historyCoordinator = HistoryCoordinator(container: container)
        self.playersCoordinator = PlayersCoordinator(container: container)
    }
}

enum AppTab: Hashable {
    case home, history, players, stats
}

struct AppRootView: View {
    @State var coordinator: AppCoordinator
    @State private var showPaywallForTesting = false
    @AppStorage(Onboarding.completedKey) private var hasCompletedOnboarding = false
    @State private var showsOnboarding = Onboarding.shouldShow(
        completed: UserDefaults.standard.bool(forKey: Onboarding.completedKey)
    )

    var body: some View {
        if showsOnboarding {
            OnboardingView {
                hasCompletedOnboarding = true
                withAnimation { showsOnboarding = false }
            }
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeRootView(coordinator: coordinator.homeCoordinator)
                .tabItem { Label("Play", systemImage: "play.circle.fill") }
                .tag(AppTab.home)

            HistoryRootView(coordinator: coordinator.historyCoordinator)
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(AppTab.history)

            PlayersRootView(coordinator: coordinator.playersCoordinator)
                .tabItem { Label("Players", systemImage: "person.2.fill") }
                .tag(AppTab.players)

            StatsView(viewModel: StatsViewModel(fetchSessions: coordinator.container.fetchSessionsUseCase))
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppTab.stats)
        }
        .sheet(isPresented: $showPaywallForTesting) {
            PaywallView()
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--uitesting-paywall") {
                showPaywallForTesting = true
            }
        }
    }
}
