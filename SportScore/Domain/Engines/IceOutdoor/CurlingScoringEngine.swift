import Foundation

struct CurlingConfig: Codable, Sendable {
    var endsInMatch: Int = 10
    var hammerStartTeam: String = "home"
}

/// Each team records its stones for every end (0 when the other team scored).
final class CurlingScoringEngine: ScoringEngine {
    let sport: SportType = .curling

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: CurlingConfig.self) ?? CurlingConfig()
        let endsPlayed = session.frames(for: playerID).count
        guard endsPlayed < config.endsInMatch else {
            return .rejected("All \(config.endsInMatch) ends already recorded.")
        }
        guard (0...8).contains(entry.value) else { return .rejected("An end scores 0 to 8 stones.") }
        let isBlankEnd = entry.metadata?["blank"] == "true"
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value

        return fixedLengthResult(
            display: DisplayScore(
                primary: "\(total)",
                secondary: "End \(endsPlayed + 1)/\(config.endsInMatch)",
                detail: isBlankEnd ? "Blank end" : nil
            ),
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= config.endsInMatch }
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: CurlingConfig.self) ?? CurlingConfig()
        return session.players.allSatisfy { session.frames(for: $0.id).count >= config.endsInMatch }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let config = session.config(as: CurlingConfig.self) ?? CurlingConfig()
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)", secondary: "Ends \(session.frames(for: playerID).count)/\(config.endsInMatch)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: CurlingConfig.self) ?? CurlingConfig()
        let ends = session.frames(for: playerID).count
        guard ends < config.endsInMatch else { return EntryContext(prompt: "All ends recorded", isPlayerFinished: true) }
        return EntryContext(prompt: "End \(ends + 1)/\(config.endsInMatch) · stones scored (0 if none)", maxValue: 8)
    }
}
