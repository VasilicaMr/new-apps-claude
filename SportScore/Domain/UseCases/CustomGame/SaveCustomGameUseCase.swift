import Foundation

struct SaveCustomGameUseCase {
    let customGameRepo: any CustomGameRepository

    /// Creates or updates a custom game. Built-in templates are never stored.
    func execute(_ game: HouseGame) async throws {
        guard game.isCustom else { return }
        try await customGameRepo.save(game)
    }
}
