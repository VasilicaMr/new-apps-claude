import Foundation

struct DeleteSessionUseCase {
    let sessionRepo: any SessionRepository

    func execute(id: UUID) async throws {
        try await sessionRepo.delete(id: id)
    }
}
