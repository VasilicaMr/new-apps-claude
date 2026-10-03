import Foundation

final class RingTossScoringEngine: ScoringEngine {
    let sport: SportType = .ringToss

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        return ScoringResult(displayScore: DisplayScore(primary: "\(total)"))
    }

    func isGameOver(_ session: GameSession) -> Bool { false }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
