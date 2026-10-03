import Foundation

struct FetchPlayersUseCase {
    let playerRepo: any PlayerRepository

    func execute() async throws -> [Player] {
        try await playerRepo.fetchAll()
    }
}
