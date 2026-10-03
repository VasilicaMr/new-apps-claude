import Foundation

struct PokerConfig: Codable, Sendable {
    var startingStack: Int = 10000
    var blindLevel: Int = 1
}

final class PokerTournamentEngine: ScoringEngine {
    let sport: SportType = .pokerTournament

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let before = stack(for: playerID, in: session)
        guard before > 0 else { return .rejected("This player has been eliminated.") }
        let currentStack = before + entry.value
        let isEliminated = currentStack <= 0

        // The tournament ends when only one player still has chips.
        let survivors = session.players.filter { p in
            p.id == playerID ? !isEliminated : stack(for: p.id, in: session) > 0
        }
        let isOver = session.players.count > 1 && survivors.count <= 1

        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(max(0, currentStack))",
                secondary: isEliminated ? "Eliminated" : "In play"
            ),
            isGameOver: isOver,
            winner: isOver ? survivors.first?.id : nil,
            notes: isEliminated ? "Player eliminated" : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        session.players.filter { stack(for: $0.id, in: session) > 0 }.count <= 1
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let s = stack(for: playerID, in: session)
        return DisplayScore(primary: "\(max(0, s))", secondary: s > 0 ? "In play" : "Eliminated")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let s = stack(for: playerID, in: session)
        return EntryContext(
            prompt: s > 0 ? "Stack \(s)" : "Eliminated",
            maxValue: max(0, s),
            allowsNegative: true,
            isPlayerFinished: s <= 0
        )
    }

    private func stack(for playerID: UUID, in session: GameSession) -> Int {
        let config = session.config(as: PokerConfig.self) ?? PokerConfig()
        return config.startingStack + session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
    }
}
