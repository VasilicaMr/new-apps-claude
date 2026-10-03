import SwiftUI

/// Hosts the `NavigationStack` driven by the coordinator's path. The only place
/// that declares navigation destinations.
struct RootView: View {
    // First-launch onboarding (spec §6): shown once per install, per platform
    // (`UserDefaults` isn't shared between the iOS and macOS apps, which is
    // exactly what "first install" should mean on each). Purely informational
    // — finishing or skipping it just flips this to true forever.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var coordinator: AppCoordinator
    // Owned here as @State (not built inline in `body`) for the same reason
    // `coordinator` is: `body` re-evaluates on every `coordinator.path`
    // change (every wizard step, every back/forward), and `NavigationStack`'s
    // root content closure re-runs along with it. Calling
    // `container.makeHomeModel()` directly inside that closure used to hand
    // `HomeView` a *brand new*, empty `HomeViewModel` on every navigation
    // event — its one-time `.task` never got a chance to reload, so
    // returning to Home (via back, or "Done" after export) showed the
    // empty state even with saved projects. One stable instance fixes it.
    @State private var homeModel: HomeViewModel
    private let container: DIContainer

    init(container: DIContainer) {
        self.container = container
        _coordinator = State(initialValue: AppCoordinator(container: container))
        _homeModel = State(initialValue: container.makeHomeModel())
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding || skipOnboardingForUITests {
                mainContent
            } else {
                OnboardingView(onFinish: { hasCompletedOnboarding = true })
            }
        }
        .tint(Theme.Palette.accent)
        .preferredColorScheme(.dark)
    }

    private var mainContent: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(model: homeModel, coordinator: coordinator)
                .navigationDestination(for: AppRoute.self) { route in
                    coordinator.view(for: route)
                }
        }
        .sheet(item: $coordinator.openHouseModel) { model in
            OpenHouseSheet(model: model, onCreated: coordinator.openCreatedPost)
        }
        .environment(container.subscriptionManager)
        #if os(macOS)
        // Shared with the Settings scene and the Inbox window (App.swift) —
        // one long-lived instance so watching keeps running regardless of
        // which window is frontmost.
        .environment(container.inboxModel)
        #endif
    }

    /// UI tests launch straight into the wizard (`-UITestSeedClips`) and
    /// assert on `home.newVideoButton` appearing immediately — a first-launch
    /// simulator has no `hasCompletedOnboarding` default, so without this
    /// they'd hit onboarding instead. DEBUG-only, like every other UI-test seam.
    private var skipOnboardingForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-UITestSkipOnboarding")
        #else
        false
        #endif
    }
}
