import Foundation

struct AxeThrowingConfig: Codable, Sendable {
    var ruleset: String = "WATL"
    var throwsPerMatch: Int = 5
    var matchesInSet: Int = 3
    var killshotEnabled: Bool = true
    var zoneValues: [String: Int] = ["bullseye": 6, "ring1": 4, "ring2": 3, "ring3": 2, "ring4": 1, "clutch": 7]
}

final class AxeThrowingScoringEngine: ScoringEngine {
    let sport: SportType = .axeThrowing

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: AxeThrowingConfig.self) ?? AxeThrowingConfig()
        let allEntries = session.allEntries(for: playerID)
        let throwsPerSet = config.throwsPerMatch * config.matchesInSet
        guard allEntries.count < throwsPerSet else {
            return .rejected("All \(throwsPerSet) throws already taken.")
        }
        guard (0...7).contains(entry.value) else {
            return .rejected("An axe throw scores between 0 and 7.")
        }
        let runningTotal = allEntries.reduce(0) { $0 + $1.value } + entry.value
        let currentMatch = allEntries.count / config.throwsPerMatch + 1

        return fixedLengthResult(
            display: DisplayScore(primary: "\(runningTotal)", secondary: "Match \(currentMatch)"),
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= throwsPerSet }
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: AxeThrowingConfig.self) ?? AxeThrowingConfig()
        let total = config.throwsPerMatch * config.matchesInSet
        return session.players.allSatisfy { session.allEntries(for: $0.id).count >= total }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: AxeThrowingConfig.self) ?? AxeThrowingConfig()
        let thrown = session.allEntries(for: playerID).count
        let total = config.throwsPerMatch * config.matchesInSet
        guard thrown < total else { return EntryContext(prompt: "All throws taken", isPlayerFinished: true) }
        return EntryContext(prompt: "Throw \(thrown + 1)/\(total) · bullseye 6, clutch 7", maxValue: 7)
    }
}
