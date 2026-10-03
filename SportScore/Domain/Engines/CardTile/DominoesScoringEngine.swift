import Foundation

struct DominoesConfig: Codable, Sendable {
    var pointsToWin: Int = 150
}

final class DominoesScoringEngine: ScoringEngine {
    let sport: SportType = .dominoes
    let variant: String
    init(variant: String) { self.variant = variant }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: DominoesConfig.self) ?? DominoesConfig()
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let isWin = total >= config.pointsToWin

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: "\(total)/\(config.pointsToWin)"),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: DominoesConfig.self) ?? DominoesConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.pointsToWin
        }
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: DominoesConfig.self) ?? DominoesConfig()
        return EntryContext(prompt: "\(variant) · first to \(config.pointsToWin)")
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
