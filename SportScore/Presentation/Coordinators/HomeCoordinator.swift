import SwiftUI

enum HomeRoute: Hashable {
    case sportList
    case sessionSetup(SportType)
    case liveScore(sessionID: UUID)
    case sessionResult(sessionID: UUID)
}

@Observable
@MainActor
final class HomeCoordinator {
    var navigationPath = NavigationPath()
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func push(_ route: HomeRoute) {
        navigationPath.append(route)
    }

    func pop() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    @ViewBuilder
    func view(for route: HomeRoute) -> some View {
        switch route {
        case .sportList:
            SportListView(
                viewModel: SportListViewModel(),
                coordinator: self
            )
        case .sessionSetup(let sport):
            SessionSetupView(
                viewModel: SessionSetupViewModel(
                    sport: sport,
                    startSession: container.startSessionUseCase,
                    fetchPlayers: container.fetchPlayersUseCase,
                    createPlayer: container.createPlayerUseCase
                ),
                coordinator: self
            )
        case .liveScore(let id):
            LiveScoreView(
                viewModel: LiveScoreViewModel(
                    sessionID: id,
                    fetchSessions: container.fetchSessionsUseCase,
                    addEntry: container.addScoreEntryUseCase,
                    computeScore: container.computeScoreUseCase,
                    undo: container.undoLastEntryUseCase,
                    endSession: container.endSessionUseCase
                ),
                coordinator: self
            )
        case .sessionResult(let id):
            SessionDetailView(
                viewModel: SessionDetailViewModel(
                    sessionID: id,
                    fetchSessions: container.fetchSessionsUseCase
                )
            )
        }
    }
}

struct HomeRootView: View {
    @State var coordinator: HomeCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            HomeView(coordinator: coordinator)
                .navigationDestination(for: HomeRoute.self) { route in
                    coordinator.view(for: route)
                }
        }
    }
}
