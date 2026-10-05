import SwiftUI
import SwiftData

@main
struct ScoreCapTVApp: App {
    @State private var coordinator = TVAppCoordinator(container: AppContainer())

    var body: some Scene {
        WindowGroup {
            TVRootView(coordinator: coordinator)
                .modelContainer(coordinator.container.modelContainer)
                .task { await PremiumManager.shared.initialize() }
                .task { await PremiumManager.shared.observeTransactions() }
        }
    }
}
