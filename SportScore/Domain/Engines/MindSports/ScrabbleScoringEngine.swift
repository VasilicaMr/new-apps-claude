import Foundation

/// Entry value already includes the +50 bingo bonus; a challenged-off word is recorded as 0.
final class ScrabbleScoringEngine: ScoringEngine {
    let sport: SportType = .scrabble

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let isBingo = entry.metadata?["bingo"] == "true"
        let isChallenge = entry.metadata?["challenged"] == "true"

        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(total)",
                secondary: isBingo ? "BINGO +50" : nil,
                detail: isChallenge ? "Challenged off" : nil
            )
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let entries = session.allEntries(for: playerID)
        let total = entries.reduce(0) { $0 + $1.value }
        let bingos = entries.filter { $0.metadata?["bingo"] == "true" }.count
        return DisplayScore(primary: "\(total)", secondary: "\(entries.count) turns", detail: bingos > 0 ? "\(bingos) bingo\(bingos == 1 ? "" : "s")" : nil)
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        // Negative values allow end-of-game rack penalties.
        EntryContext(prompt: "Word score · use End game when the bag is empty", allowsNegative: true)
    }
}
