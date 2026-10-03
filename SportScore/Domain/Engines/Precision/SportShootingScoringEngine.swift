import Foundation

struct SportShootingConfig: Codable, Sendable {
    var useDecimal: Bool = false
    var shotsPerSeries: Int = 10
    var seriesCount: Int = 6
    var penaltyValue: Int = 0
}

final class SportShootingScoringEngine: ScoringEngine {
    let sport: SportType = .sportShooting

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: SportShootingConfig.self) ?? SportShootingConfig()
        let allEntries = session.allEntries(for: playerID)
        let totalTarget = config.shotsPerSeries * config.seriesCount
        guard allEntries.count < totalTarget else {
            return .rejected("All \(totalTarget) shots already fired.")
        }
        guard (0...10).contains(entry.value) else {
            return .rejected("A shot scores between 0 and 10.")
        }
        let runningTotal = allEntries.reduce(0) { $0 + $1.value } + entry.value
        let shotsTaken = allEntries.count + 1
        let currentSeries = allEntries.count / config.shotsPerSeries + 1

        return fixedLengthResult(
            display: DisplayScore(
                primary: "\(runningTotal)",
                secondary: "Series \(currentSeries) · Shot \(allEntries.count % config.shotsPerSeries + 1)"
            ),
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= totalTarget },
            turnAdvances: shotsTaken % config.shotsPerSeries == 0
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: SportShootingConfig.self) ?? SportShootingConfig()
        let total = config.shotsPerSeries * config.seriesCount
        return session.players.allSatisfy { session.allEntries(for: $0.id).count >= total }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: SportShootingConfig.self) ?? SportShootingConfig()
        let shot = session.allEntries(for: playerID).count
        guard shot < config.shotsPerSeries * config.seriesCount else {
            return EntryContext(prompt: "All series complete", isPlayerFinished: true)
        }
        return EntryContext(
            prompt: "Series \(shot / config.shotsPerSeries + 1)/\(config.seriesCount) · Shot \(shot % config.shotsPerSeries + 1)",
            maxValue: 10
        )
    }
}
