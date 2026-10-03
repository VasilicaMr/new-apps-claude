import Foundation

struct PoolConfig: Codable, Sendable {
    var racksInMatch: Int = 7
    var foulRules: Bool = true
}

final class PoolScoringEngine: ScoringEngine {
    let sport: SportType = .pool
    let variant: String

    init(variant: String) { self.variant = variant }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: PoolConfig.self) ?? PoolConfig()
        let wins = rackWins(for: playerID, in: session) + (entry.value == 1 ? 1 : 0)
        let isMatch = wins >= config.racksInMatch

        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(wins)",
                secondary: "\(wins)/\(config.racksInMatch) racks"
            ),
            isGameOver: isMatch,
            winner: isMatch ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: PoolConfig.self) ?? PoolConfig()
        return session.players.contains { rackWins(for: $0.id, in: session) >= config.racksInMatch }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let wins = rackWins(for: playerID, in: session)
        return DisplayScore(primary: "\(wins)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: PoolConfig.self) ?? PoolConfig()
        return EntryContext(prompt: "\(variant) · race to \(config.racksInMatch) racks")
    }

    private func rackWins(for playerID: UUID, in session: GameSession) -> Int {
        session.allEntries(for: playerID).filter { $0.value == 1 }.count
    }
}
