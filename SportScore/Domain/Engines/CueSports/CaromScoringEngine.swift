import Foundation

struct CaromConfig: Codable, Sendable {
    var targetCaroms: Int = 40
}

final class CaromScoringEngine: ScoringEngine {
    let sport: SportType
    let variant: String

    init(variant: String) {
        self.variant = variant
        self.sport = variant == "3-Cushion" ? .cushionCaroms : .caroms
    }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: CaromConfig.self) ?? CaromConfig()
        let allEntries = session.allEntries(for: playerID)
        let totalCaroms = allEntries.reduce(0) { $0 + $1.value } + entry.value
        let innings = countInnings(session: session, playerID: playerID) + 1
        let avg = innings > 0 ? String(format: "%.2f", Double(totalCaroms) / Double(innings)) : "0.00"
        let isWin = totalCaroms >= config.targetCaroms

        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(totalCaroms)",
                secondary: "Inning \(innings)",
                detail: "Avg \(avg)"
            ),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: CaromConfig.self) ?? CaromConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.targetCaroms
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }

    private func countInnings(session: GameSession, playerID: UUID) -> Int {
        session.frames(for: playerID).count
    }
}
