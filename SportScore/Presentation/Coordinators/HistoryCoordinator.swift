import SwiftUI

enum HistoryRoute: Hashable {
    case sessionDetail(sessionID: UUID)
}

@Observable
@MainActor
final class HistoryCoordinator {
    var navigationPath = NavigationPath()
    let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func push(_ route: HistoryRoute) {
        navigationPath.append(route)
    }

    func pop() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    @ViewBuilder
    func view(for route: HistoryRoute) -> some View {
        switch route {
        case .sessionDetail(let id):
            SessionDetailView(
                viewModel: SessionDetailViewModel(
                    sessionID: id,
                    fetchSessions: container.fetchSessionsUseCase
                )
            )
        }
    }
}

struct HistoryRootView: View {
    @State var coordinator: HistoryCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            HistoryView(
                viewModel: HistoryViewModel(fetchSessions: coordinator.container.fetchSessionsUseCase),
                coordinator: coordinator
            )
            .navigationDestination(for: HistoryRoute.self) { route in
                coordinator.view(for: route)
            }
        }
    }
}
