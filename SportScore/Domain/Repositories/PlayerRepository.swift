import Foundation

protocol PlayerRepository: Sendable {
    func fetchAll() async throws -> [Player]
    func save(_ player: Player) async throws
    func delete(id: UUID) async throws
}
