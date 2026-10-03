import Foundation

struct AirHockeyConfig: Codable, Sendable {
    var pointsToWin: Int = 7
    var gamesInSeries: Int = 1
}

final class AirHockeyScoringEngine: ScoringEngine {
    let sport: SportType = .airHockey

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: AirHockeyConfig.self) ?? AirHockeyConfig()
        let goals = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let opponentID = session.players.first { $0.id != playerID }?.id
        let opGoals = opponentID.map { session.allEntries(for: $0).reduce(0) { $0 + $1.value } } ?? 0
        let isWin = goals >= config.pointsToWin

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(goals)-\(opGoals)"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: AirHockeyConfig.self) ?? AirHockeyConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.pointsToWin
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let goals = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(goals)")
    }
}
