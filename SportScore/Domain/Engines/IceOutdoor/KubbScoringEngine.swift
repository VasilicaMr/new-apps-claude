import Foundation

/// Entries: label "kubb" (value = kubbs toppled) or metadata["kingHit"] to win.
final class KubbScoringEngine: ScoringEngine {
    let sport: SportType = .kubb

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        if entry.metadata?["kingHit"] == "true" {
            return ScoringResult(
                displayScore: DisplayScore(primary: "WIN", secondary: "King toppled!"),
                isGameOver: true,
                winner: playerID
            )
        }
        let kubbs = kubbCount(session.allEntries(for: playerID) + [entry])
        return ScoringResult(
            displayScore: DisplayScore(primary: "\(kubbs)", secondary: "Kubbs toppled")
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        DisplayScore(primary: "\(kubbCount(session.allEntries(for: playerID)))", secondary: "Kubbs")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        EntryContext(prompt: "Kubbs toppled this turn, or topple the king to win", maxValue: 10)
    }

    private func kubbCount(_ entries: [ScoreEntry]) -> Int {
        entries.filter { $0.label == "kubb" }.reduce(0) { $0 + $1.value }
    }
}
