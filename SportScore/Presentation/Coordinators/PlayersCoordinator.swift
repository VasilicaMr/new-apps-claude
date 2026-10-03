import SwiftUI

@Observable
@MainActor
final class PlayersCoordinator {
    var navigationPath = NavigationPath()
    let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }
}

struct PlayersRootView: View {
    @State var coordinator: PlayersCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            PlayersView(
                viewModel: PlayersViewModel(
                    fetchPlayers: coordinator.container.fetchPlayersUseCase,
                    createPlayer: coordinator.container.createPlayerUseCase,
                    deletePlayer: coordinator.container.deletePlayerUseCase
                )
            )
        }
    }
}
