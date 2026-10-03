import Foundation

struct ArmWrestlingConfig: Codable, Sendable {
    var pullsPerMatch: Int = 5
}

/// Best-of-N pulls. Each entry is one pull recorded for the player who won it (value 1).
final class ArmWrestlingScoringEngine: ScoringEngine {
    let sport: SportType = .armWrestling

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: ArmWrestlingConfig.self) ?? ArmWrestlingConfig()
        let pullsNeeded = config.pullsPerMatch / 2 + 1
        let wins = session.allEntries(for: playerID).filter { $0.value == 1 }.count + (entry.value == 1 ? 1 : 0)
        let pulls = session.chronologicalEntries.count + 1
        let isWin = wins >= pullsNeeded

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(wins)", secondary: "Pull \(pulls) · first to \(pullsNeeded)"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let wins = session.allEntries(for: playerID).filter { $0.value == 1 }.count
        return DisplayScore(primary: "\(wins)", secondary: "Pulls won")
    }
}
