import Foundation

struct LawnBowlsConfig: Codable, Sendable {
    var endsInMatch: Int = 18
    var targetPoints: Int? = nil
}

/// Each player records their shots for every end (0 if the opponent held shot).
final class LawnBowlsScoringEngine: ScoringEngine {
    let sport: SportType = .lawnBowls

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: LawnBowlsConfig.self) ?? LawnBowlsConfig()
        let endsPlayed = session.frames(for: playerID).count
        if config.targetPoints == nil && endsPlayed >= config.endsInMatch {
            return .rejected("All \(config.endsInMatch) ends already recorded.")
        }
        guard (0...8).contains(entry.value) else { return .rejected("An end scores 0 to 8 shots.") }
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let display = DisplayScore(primary: "\(total)", secondary: "End \(endsPlayed + 1)")

        if let target = config.targetPoints {
            let isWin = total >= target
            return ScoringResult(displayScore: display, isGameOver: isWin, winner: isWin ? playerID : nil)
        }
        return fixedLengthResult(
            display: display,
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= config.endsInMatch }
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: LawnBowlsConfig.self) ?? LawnBowlsConfig()
        if let target = config.targetPoints {
            return session.totals().values.contains { $0 >= target }
        }
        return session.players.allSatisfy { session.frames(for: $0.id).count >= config.endsInMatch }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: LawnBowlsConfig.self) ?? LawnBowlsConfig()
        let ends = session.frames(for: playerID).count
        if config.targetPoints == nil && ends >= config.endsInMatch {
            return EntryContext(prompt: "All ends recorded", isPlayerFinished: true)
        }
        return EntryContext(prompt: "End \(ends + 1) · shots (0 if you didn't score)", maxValue: 8)
    }
}
