import Foundation

struct FetchSessionsUseCase {
    let sessionRepo: any SessionRepository

    func execute(activeOnly: Bool = false) async throws -> [GameSession] {
        activeOnly ? try await sessionRepo.fetchActive() : try await sessionRepo.fetchAll()
    }
}
