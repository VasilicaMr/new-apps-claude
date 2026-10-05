import SwiftData
import Foundation

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer = PersistenceContainer.make()

    lazy var playerRepo: any PlayerRepository = PlayerRepositoryImpl(container: modelContainer)
    lazy var sessionRepo: any SessionRepository = SessionRepositoryImpl(container: modelContainer)
    lazy var scoreRepo: any ScoreRepository = ScoreRepositoryImpl(container: modelContainer)
    lazy var customGameRepo: any CustomGameRepository = CustomGameRepositoryImpl(container: modelContainer)

    var createPlayerUseCase: CreatePlayerUseCase { CreatePlayerUseCase(playerRepo: playerRepo) }
    var fetchPlayersUseCase: FetchPlayersUseCase { FetchPlayersUseCase(playerRepo: playerRepo) }
    var deletePlayerUseCase: DeletePlayerUseCase { DeletePlayerUseCase(playerRepo: playerRepo) }
    var startSessionUseCase: StartSessionUseCase { StartSessionUseCase(sessionRepo: sessionRepo) }
    var endSessionUseCase: EndSessionUseCase { EndSessionUseCase(sessionRepo: sessionRepo) }
    var fetchSessionsUseCase: FetchSessionsUseCase { FetchSessionsUseCase(sessionRepo: sessionRepo) }
    var deleteSessionUseCase: DeleteSessionUseCase { DeleteSessionUseCase(sessionRepo: sessionRepo) }
    var addScoreEntryUseCase: AddScoreEntryUseCase { AddScoreEntryUseCase(scoreRepo: scoreRepo) }
    var undoLastEntryUseCase: UndoLastEntryUseCase { UndoLastEntryUseCase(scoreRepo: scoreRepo) }
    var fetchCustomGamesUseCase: FetchCustomGamesUseCase { FetchCustomGamesUseCase(customGameRepo: customGameRepo) }
    var saveCustomGameUseCase: SaveCustomGameUseCase { SaveCustomGameUseCase(customGameRepo: customGameRepo) }
    var deleteCustomGameUseCase: DeleteCustomGameUseCase { DeleteCustomGameUseCase(customGameRepo: customGameRepo) }
    var computeScoreUseCase: ComputeScoreUseCase { ComputeScoreUseCase(engineFactory: ScoringEngineFactory()) }

    #if os(iOS)
    lazy var appCoordinator = AppCoordinator(container: self)
    #endif
}
