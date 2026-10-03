import Foundation

final class CribbageScoringEngine: ScoringEngine {
    let sport: SportType = .cribbage

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let isWin = total >= 121

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: "Peg \(total)/121"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= 121
        }
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        EntryContext(prompt: "Pegging / hand / crib points · first to 121")
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
