import Foundation

struct StartSessionUseCase {
    let sessionRepo: any SessionRepository

    func execute(sport: SportType, variant: String?, players: [Player], configJSON: Data? = nil) async throws -> GameSession {
        var session = GameSession(sport: sport, variant: variant, players: players, configJSON: configJSON)
        try await sessionRepo.save(session)
        return session
    }
}
