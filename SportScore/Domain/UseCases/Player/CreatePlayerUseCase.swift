import Foundation

struct CreatePlayerUseCase {
    let playerRepo: any PlayerRepository

    func execute(name: String, avatarData: Data? = nil) async throws -> Player {
        let player = Player(name: name, avatarData: avatarData)
        try await playerRepo.save(player)
        return player
    }
}
