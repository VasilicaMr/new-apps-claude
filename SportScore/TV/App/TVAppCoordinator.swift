import SwiftUI

enum TVTab: Hashable {
    case home, plans, history, players, stats
}

enum TVHomeRoute: Hashable {
    case sessionSetup(SportType)
    case houseGameSetup(HouseGame)
    /// `nil` creates a new custom game; a built-in game opens as an editable copy.
    case customGameEditor(HouseGame?)
    case sessionResult(sessionID: UUID)
}

enum TVHistoryRoute: Hashable {
    case sessionDetail(sessionID: UUID)
}

/// Root coordinator for Apple TV. Mirrors the iOS coordinators, except that the live
/// scoreboard is presented full screen (so the tab bar never covers the scores) and
/// can be left with the Menu button and resumed later.
@Observable
@MainActor
final class TVAppCoordinator {
    var selectedTab: TVTab = .home
    var homePath: [TVHomeRoute] = []
    var historyPath = NavigationPath()
    /// The session currently shown on the full-screen scoreboard.
    var liveSessionID: UUID?

    let container: AppContainer
    let customGames: CustomGamesViewModel
    let plans = GamePlansStore(defaults: TVAppCoordinator.planDefaults())

    init(container: AppContainer) {
        self.container = container
        self.customGames = CustomGamesViewModel(
            fetchGames: container.fetchCustomGamesUseCase,
            saveGame: container.saveCustomGameUseCase,
            deleteGame: container.deleteCustomGameUseCase
        )
    }

    /// UI tests start with no plans and never touch the real ones.
    private static func planDefaults() -> UserDefaults {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let defaults = UserDefaults(suiteName: "uitesting.plans") {
            defaults.removePersistentDomain(forName: "uitesting.plans")
            return defaults
        }
        #endif
        return .standard
    }

    func showSetup(for sport: SportType) {
        homePath.append(.sessionSetup(sport))
    }

    func showSetup(for game: HouseGame) {
        homePath.append(.houseGameSetup(game))
    }

    func showEditor(for game: HouseGame?) {
        homePath.append(.customGameEditor(game))
    }

    /// After saving a game from the editor: go back, or replace the editor with its setup screen.
    func finishEditing(_ game: HouseGame, play: Bool) {
        if case .customGameEditor? = homePath.last { homePath.removeLast() }
        // Opened from that game's setup screen: refresh it with the new rules.
        if case .houseGameSetup(let previous)? = homePath.last, previous.id == game.id {
            homePath[homePath.count - 1] = .houseGameSetup(game)
        } else if play {
            showSetup(for: game)
        }
    }

    func closeEditor() {
        if case .customGameEditor? = homePath.last { homePath.removeLast() }
        // The game was deleted, so its setup screen can't stay open either.
        if case .houseGameSetup(let game)? = homePath.last, game.isCustom,
           !customGames.games.contains(where: { $0.id == game.id }) {
            homePath.removeLast()
        }
    }

    func startLiveScore(sessionID: UUID) {
        liveSessionID = sessionID
    }

    /// Called once the scoreboard is on screen. Closing the setup screen at the same moment the
    /// scoreboard opens doesn't take effect, which left "Start" focused behind the game (a second
    /// click started a duplicate game). So the setup screen is closed only now.
    func liveScoreDidAppear() {
        homePath.removeAll { route in
            switch route {
            case .sessionSetup, .houseGameSetup, .customGameEditor: true
            case .sessionResult: false
            }
        }
    }

    func closeLiveScore() {
        liveSessionID = nil
    }

    func showResult(sessionID: UUID) {
        liveSessionID = nil
        selectedTab = .home
        homePath = [.sessionResult(sessionID: sessionID)]
    }

    /// Leaves the result screen for the list of games, ready to start a new one.
    func showGames() {
        selectedTab = .home
        homePath.removeAll()
    }

    // MARK: - View factories

    func liveScoreView(sessionID: UUID) -> some View {
        TVLiveScoreView(
            viewModel: LiveScoreViewModel(
                sessionID: sessionID,
                fetchSessions: container.fetchSessionsUseCase,
                addEntry: container.addScoreEntryUseCase,
                computeScore: container.computeScoreUseCase,
                undo: container.undoLastEntryUseCase,
                endSession: container.endSessionUseCase
            ),
            coordinator: self
        )
    }

    @ViewBuilder
    func view(for route: TVHomeRoute) -> some View {
        switch route {
        case .sessionSetup(let sport):
            TVSessionSetupView(
                viewModel: SessionSetupViewModel(
                    sport: sport,
                    startSession: container.startSessionUseCase,
                    fetchPlayers: container.fetchPlayersUseCase,
                    createPlayer: container.createPlayerUseCase
                ),
                coordinator: self
            )
        case .houseGameSetup(let game):
            TVSessionSetupView(
                viewModel: SessionSetupViewModel(
                    sport: .houseGame,
                    configJSON: game.configJSON,
                    startSession: container.startSessionUseCase,
                    fetchPlayers: container.fetchPlayersUseCase,
                    createPlayer: container.createPlayerUseCase
                ),
                coordinator: self,
                houseGame: game
            )
            .id(game) // fresh setup state when the game's rules are edited
        case .customGameEditor(let game):
            TVCustomGameEditorView(game: game, coordinator: self)
        case .sessionResult(let id):
            sessionDetailView(sessionID: id, isResult: true)
        }
    }

    @ViewBuilder
    func view(for route: TVHistoryRoute) -> some View {
        switch route {
        case .sessionDetail(let id):
            sessionDetailView(sessionID: id)
        }
    }

    private func sessionDetailView(sessionID: UUID, isResult: Bool = false) -> some View {
        TVSessionDetailView(
            viewModel: SessionDetailViewModel(sessionID: sessionID, fetchSessions: container.fetchSessionsUseCase),
            coordinator: self,
            isResult: isResult
        )
    }
}

struct TVRootView: View {
    @Bindable var coordinator: TVAppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            Tab("Play", systemImage: "play.circle.fill", value: TVTab.home) {
                NavigationStack(path: $coordinator.homePath) {
                    TVHomeView(coordinator: coordinator)
                        .navigationDestination(for: TVHomeRoute.self) { coordinator.view(for: $0) }
                }
            }

            Tab("Plans", systemImage: "calendar", value: TVTab.plans) {
                TVPlansView(coordinator: coordinator)
            }

            Tab("History", systemImage: "clock.fill", value: TVTab.history) {
                NavigationStack(path: $coordinator.historyPath) {
                    TVHistoryView(
                        viewModel: HistoryViewModel(
                            fetchSessions: coordinator.container.fetchSessionsUseCase,
                            deleteSession: coordinator.container.deleteSessionUseCase
                        )
                    )
                    .navigationDestination(for: TVHistoryRoute.self) { coordinator.view(for: $0) }
                }
            }

            Tab("Players", systemImage: "person.2.fill", value: TVTab.players) {
                NavigationStack {
                    TVPlayersView(
                        viewModel: PlayersViewModel(
                            fetchPlayers: coordinator.container.fetchPlayersUseCase,
                            createPlayer: coordinator.container.createPlayerUseCase,
                            deletePlayer: coordinator.container.deletePlayerUseCase
                        )
                    )
                }
            }

            Tab("Stats", systemImage: "chart.bar.fill", value: TVTab.stats) {
                NavigationStack {
                    TVStatsView(viewModel: StatsViewModel(fetchSessions: coordinator.container.fetchSessionsUseCase))
                }
            }
        }
        .tvThemed()
        .fullScreenCover(isPresented: liveScorePresented) {
            if let id = coordinator.liveSessionID {
                coordinator.liveScoreView(sessionID: id)
                    .id(id)
                    .tvThemed()
            }
        }
    }

    private var liveScorePresented: Binding<Bool> {
        Binding(
            get: { coordinator.liveSessionID != nil },
            set: { if !$0 { coordinator.closeLiveScore() } }
        )
    }
}
