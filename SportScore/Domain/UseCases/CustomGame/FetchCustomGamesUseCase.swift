import Foundation

struct FetchCustomGamesUseCase {
    let customGameRepo: any CustomGameRepository

    func execute() async throws -> [HouseGame] {
        try await customGameRepo.fetchAll()
    }
}
