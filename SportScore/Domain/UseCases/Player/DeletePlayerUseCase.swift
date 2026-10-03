import Foundation

struct DeletePlayerUseCase {
    let playerRepo: any PlayerRepository

    func execute(id: UUID) async throws {
        try await playerRepo.delete(id: id)
    }
}
