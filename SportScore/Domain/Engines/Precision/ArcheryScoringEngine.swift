import Foundation

struct ArcheryConfig: Codable, Sendable {
    var arrowsPerEnd: Int = 6
    var endsPerRound: Int = 10
}

final class ArcheryScoringEngine: ScoringEngine {
    let sport: SportType = .archery

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: ArcheryConfig.self) ?? ArcheryConfig()
        let allEntries = session.allEntries(for: playerID)
        let totalTarget = config.arrowsPerEnd * config.endsPerRound
        guard allEntries.count < totalTarget else {
            return .rejected("All \(totalTarget) arrows already shot.")
        }
        let totalArrows = allEntries.count + 1
        let xCount = xCount(allEntries + [entry])
        let runningTotal = allEntries.reduce(0) { $0 + $1.value } + entry.value
        let endArrows = totalArrows % config.arrowsPerEnd
        let currentEnd = (totalArrows - 1) / config.arrowsPerEnd + 1

        return fixedLengthResult(
            display: DisplayScore(
                primary: "\(runningTotal)",
                secondary: "End \(currentEnd) · Arrow \(endArrows == 0 ? config.arrowsPerEnd : endArrows)",
                detail: xCount > 0 ? "\(xCount)X" : nil
            ),
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= totalTarget },
            turnAdvances: endArrows == 0
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: ArcheryConfig.self) ?? ArcheryConfig()
        let total = config.arrowsPerEnd * config.endsPerRound
        return session.players.allSatisfy { session.allEntries(for: $0.id).count >= total }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let entries = session.allEntries(for: playerID)
        let total = entries.reduce(0) { $0 + $1.value }
        let x = xCount(entries)
        return DisplayScore(primary: "\(total)", detail: x > 0 ? "\(x)X" : nil)
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: ArcheryConfig.self) ?? ArcheryConfig()
        let shot = session.allEntries(for: playerID).count
        let total = config.arrowsPerEnd * config.endsPerRound
        guard shot < total else { return EntryContext(prompt: "Round complete", isPlayerFinished: true) }
        return EntryContext(
            prompt: "End \(shot / config.arrowsPerEnd + 1)/\(config.endsPerRound) · Arrow \(shot % config.arrowsPerEnd + 1)/\(config.arrowsPerEnd)"
        )
    }

    private func xCount(_ entries: [ScoreEntry]) -> Int {
        entries.filter { $0.label == "X" || $0.metadata?["isX"] == "true" }.count
    }
}
