import Foundation

struct SkittlesConfig: Codable, Sendable {
    var throwsPerTurn: Int = 3
    var legsPerGame: Int = 3
}

final class SkittlesScoringEngine: ScoringEngine {
    let sport: SportType = .skittles

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: SkittlesConfig.self) ?? SkittlesConfig()
        guard (0...9).contains(entry.value) else { return .rejected("Skittles: 0 to 9 pins per throw.") }
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let throwIndex = session.allEntries(for: playerID).count % config.throwsPerTurn
        let turnCount = session.allEntries(for: playerID).count / config.throwsPerTurn + 1

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(total)", secondary: "Turn \(turnCount)"),
            turnAdvances: throwIndex == config.throwsPerTurn - 1
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { false }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: SkittlesConfig.self) ?? SkittlesConfig()
        let count = session.allEntries(for: playerID).count
        return EntryContext(
            prompt: "Turn \(count / config.throwsPerTurn + 1) · Throw \(count % config.throwsPerTurn + 1)/\(config.throwsPerTurn)",
            maxValue: 9
        )
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
