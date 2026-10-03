import Foundation

protocol SessionRepository: Sendable {
    func fetchAll() async throws -> [GameSession]
    func fetchActive() async throws -> [GameSession]
    func fetch(id: UUID) async throws -> GameSession?
    func save(_ session: GameSession) async throws
    func delete(id: UUID) async throws
}
