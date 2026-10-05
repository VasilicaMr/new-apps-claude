import Foundation

/// The family's own games. Shared by the home screen and the editor so both stay in sync.
@Observable
@MainActor
final class CustomGamesViewModel {
    private(set) var games: [HouseGame] = []
    var errorMessage: String?

    private let fetchGames: FetchCustomGamesUseCase
    private let saveGame: SaveCustomGameUseCase
    private let deleteGame: DeleteCustomGameUseCase

    init(fetchGames: FetchCustomGamesUseCase, saveGame: SaveCustomGameUseCase, deleteGame: DeleteCustomGameUseCase) {
        self.fetchGames = fetchGames
        self.saveGame = saveGame
        self.deleteGame = deleteGame
    }

    func load() async {
        do {
            games = try await fetchGames.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves a new or edited custom game. Returns false if it could not be saved.
    @discardableResult
    func save(_ game: HouseGame) async -> Bool {
        var game = game
        game.name = game.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !game.name.isEmpty else { return false }
        do {
            try await saveGame.execute(game)
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index] = game
            } else {
                games.insert(game, at: 0)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ game: HouseGame) async {
        do {
            try await deleteGame.execute(id: game.id)
            games.removeAll { $0.id == game.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
