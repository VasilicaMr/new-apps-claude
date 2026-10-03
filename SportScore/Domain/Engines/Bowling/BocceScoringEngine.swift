import Foundation

struct BocceConfig: Codable, Sendable {
    var pointsToWin: Int = 13
}

final class BocceScoringEngine: ScoringEngine {
    let sport: SportType

    init(sport: SportType) { self.sport = sport }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: BocceConfig.self) ?? BocceConfig()
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let isWin = total >= config.pointsToWin

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: "\(total)/\(config.pointsToWin)"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: BocceConfig.self) ?? BocceConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.pointsToWin
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
