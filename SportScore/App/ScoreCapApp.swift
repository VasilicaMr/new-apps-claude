import SwiftUI
import SwiftData

@main
struct ScoreCapApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: container.appCoordinator)
                .modelContainer(container.modelContainer)
                .task { await PremiumManager.shared.initialize() }
                .task { await PremiumManager.shared.observeTransactions() }
        }
    }
}
