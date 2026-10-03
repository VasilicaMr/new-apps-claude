import Foundation

/// Entries: label "capture" (value 1) or label "gameWin" (value 0).
final class CheckersScoringEngine: ScoringEngine {
    let sport: SportType = .checkers

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let captures = captures(session.allEntries(for: playerID) + [entry])
        let isWin = entry.label == "gameWin"

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(captures)", secondary: "Captured"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil,
            turnAdvances: !isWin
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        DisplayScore(primary: "\(captures(session.allEntries(for: playerID)))", secondary: "Captured")
    }

    private func captures(_ entries: [ScoreEntry]) -> Int {
        entries.filter { $0.label != "gameWin" }.reduce(0) { $0 + $1.value }
    }
}
