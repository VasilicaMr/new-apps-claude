import Foundation

struct ShuffleboardConfig: Codable, Sendable {
    var pointsToWin: Int = 21
}

final class ShuffleboardScoringEngine: ScoringEngine {
    let sport: SportType = .shuffleboard

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: ShuffleboardConfig.self) ?? ShuffleboardConfig()
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let isWin = total >= config.pointsToWin

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: "Zone +\(entry.value)"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: ShuffleboardConfig.self) ?? ShuffleboardConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.pointsToWin
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
