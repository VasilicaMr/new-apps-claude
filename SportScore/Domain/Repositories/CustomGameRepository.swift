import Foundation

protocol CustomGameRepository: Sendable {
    func fetchAll() async throws -> [HouseGame]
    func save(_ game: HouseGame) async throws
    func delete(id: String) async throws
}
