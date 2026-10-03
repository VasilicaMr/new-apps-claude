import Foundation

/// Entries: label "hoop" (value 1) and, in Association, label "pegOut" to finish.
final class CroquetScoringEngine: ScoringEngine {
    let sport: SportType = .croquet
    let variant: String
    init(variant: String) { self.variant = variant }

    /// Golf croquet: first to 7 of 13 hoops. Association: 12 hoops per ball, then peg out.
    private var hoopsToWin: Int { variant == "Golf Croquet" ? 7 : 26 }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let hoops = hoopCount(session.allEntries(for: playerID) + [entry])
        let isPegOut = entry.label == "pegOut"
        let isWin = variant == "Golf Croquet" ? hoops >= hoopsToWin : isPegOut

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(hoops)", secondary: "Hoops"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        DisplayScore(primary: "\(hoopCount(session.allEntries(for: playerID)))", secondary: "Hoops")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        EntryContext(prompt: variant == "Golf Croquet" ? "First to 7 hoops" : "Run hoops, then peg out to win")
    }

    private func hoopCount(_ entries: [ScoreEntry]) -> Int {
        entries.filter { $0.label == "hoop" }.reduce(0) { $0 + max(1, $1.value) }
    }
}
