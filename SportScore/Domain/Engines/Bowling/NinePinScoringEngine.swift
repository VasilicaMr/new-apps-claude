import Foundation

final class NinePinScoringEngine: ScoringEngine {
    let sport: SportType = .bowlingNinePin

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        guard (0...9).contains(entry.value) else { return .rejected("Nine-pin: 0 to 9 pins per ball.") }
        let allEntries = session.allEntries(for: playerID)
        let total = allEntries.reduce(0) { $0 + $1.value } + entry.value
        let ballIndex = allEntries.count % 2
        let turnCount = allEntries.count / 2 + 1

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: "Turn \(turnCount)"),
            turnAdvances: ballIndex == 1
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { false }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let count = session.allEntries(for: playerID).count
        return EntryContext(prompt: "Turn \(count / 2 + 1) · Ball \(count % 2 + 1)", maxValue: 9)
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
