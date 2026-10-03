import Foundation

struct ZoneBasedConfig: Codable, Sendable {
    var zoneValues: [Int] = [5, 4, 3, 2, 1]
    var throwsPerRound: Int = 5
    var roundsPerMatch: Int = 5
    var targetScore: Int? = nil
}

final class ZoneBasedScoringEngine: ScoringEngine {
    let sport: SportType
    init(sport: SportType) { self.sport = sport }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: ZoneBasedConfig.self) ?? ZoneBasedConfig()
        let allEntries = session.allEntries(for: playerID)
        let totalThrows = config.throwsPerRound * config.roundsPerMatch
        guard allEntries.count < totalThrows else {
            return .rejected("All \(totalThrows) throws already taken.")
        }
        let runningTotal = allEntries.reduce(0) { $0 + $1.value } + entry.value
        let throwCount = allEntries.count + 1
        let display = DisplayScore(primary: "\(runningTotal)", secondary: "Throw \(throwCount)/\(totalThrows)")

        if let target = config.targetScore, runningTotal >= target {
            return ScoringResult(displayScore: display, isGameOver: true, winner: playerID)
        }
        return fixedLengthResult(
            display: display,
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= totalThrows },
            turnAdvances: throwCount % config.throwsPerRound == 0
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: ZoneBasedConfig.self) ?? ZoneBasedConfig()
        let totals = session.totals()
        if let target = config.targetScore, totals.values.contains(where: { $0 >= target }) { return true }
        return session.players.allSatisfy {
            session.allEntries(for: $0.id).count >= config.throwsPerRound * config.roundsPerMatch
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: ZoneBasedConfig.self) ?? ZoneBasedConfig()
        let thrown = session.allEntries(for: playerID).count
        let total = config.throwsPerRound * config.roundsPerMatch
        guard thrown < total else { return EntryContext(prompt: "All throws taken", isPlayerFinished: true) }
        return EntryContext(prompt: "Throw \(thrown + 1)/\(total)", maxValue: config.zoneValues.max())
    }
}
