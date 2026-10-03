import Foundation

struct HorseshoesConfig: Codable, Sendable {
    var pointsToWin: Int = 21
    var ringerValue: Int = 3
    var leanerValue: Int = 1
}

final class HorseshoesScoringEngine: ScoringEngine {
    let sport: SportType = .horseshoes

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: HorseshoesConfig.self) ?? HorseshoesConfig()
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let isWin = total >= config.pointsToWin
        let label = entry.label ?? (entry.value == config.ringerValue ? "Ringer" : entry.value == config.leanerValue ? "Leaner" : "Point")

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: label),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: HorseshoesConfig.self) ?? HorseshoesConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.pointsToWin
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
