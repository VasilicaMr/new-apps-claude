import Foundation

/// Generic engine for home and custom games. The rules come from the `HouseGame`
/// snapshot stored in the session, so one engine covers every template and custom game.
///
/// Entries are always positive points (or ±1 for tally games); in `.countDown` games they
/// are subtracted from the starting score, and going below zero is a bust.
struct HouseGameScoringEngine: ScoringEngine {
    let sport: SportType = .houseGame

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let rules = Self.rules(for: session)
        let scores = Self.scores(in: session, adding: entry, for: playerID)
        let score = scores[playerID] ?? 0

        if rules.mode == .countDown && score < 0 {
            return ScoringResult(
                displayScore: currentScore(for: playerID, in: session),
                isBust: true,
                notes: "Over by \(-score)"
            )
        }

        let over = Self.isOver(scores, rules: rules)
        return ScoringResult(
            displayScore: display(score, rules: rules),
            isGameOver: over,
            winner: over ? Self.winner(scores, rules: rules) : nil,
            turnAdvances: rules.entry == .points
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        Self.isOver(Self.scores(in: session), rules: Self.rules(for: session))
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let rules = Self.rules(for: session)
        return display(Self.scores(in: session)[playerID] ?? 0, rules: rules)
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let rules = Self.rules(for: session)
        guard rules.entry == .points else { return EntryContext() }
        return EntryContext(prompt: rules.mode == .countDown ? "Points scored this turn" : "Points this round")
    }

    // MARK: - Helpers

    static func rules(for session: GameSession) -> HouseGameRules {
        session.houseGame?.rules ?? HouseGameRules()
    }

    /// Current score for every player, optionally including an entry not yet recorded.
    static func scores(in session: GameSession, adding entry: ScoreEntry? = nil, for playerID: UUID? = nil) -> [UUID: Int] {
        let gameRules = rules(for: session)
        return session.totals(adding: entry, for: playerID).mapValues { total in
            gameRules.mode == .countDown ? gameRules.startingScore - total : total
        }
    }

    /// The single player currently ahead, or nil when tied.
    static func leader(in session: GameSession) -> UUID? {
        rankedWinner(scores(in: session), ranking: rules(for: session).mode == .highestWins ? .highest : .lowest)
    }

    private static func isOver(_ scores: [UUID: Int], rules: HouseGameRules) -> Bool {
        switch rules.mode {
        case .countDown:
            return scores.values.contains(0)
        case .highestWins, .lowestWins:
            guard let target = rules.target else { return false }
            return scores.values.contains { $0 >= target }
        }
    }

    private static func winner(_ scores: [UUID: Int], rules: HouseGameRules) -> UUID? {
        switch rules.mode {
        case .countDown:   return scores.first { $0.value == 0 }?.key
        case .highestWins: return rankedWinner(scores, ranking: .highest)
        case .lowestWins:  return rankedWinner(scores, ranking: .lowest)
        }
    }

    private func display(_ score: Int, rules: HouseGameRules) -> DisplayScore {
        let secondary: String? = switch rules.mode {
        case .countDown:   "from \(rules.startingScore)"
        case .highestWins: rules.target.map { score < $0 ? "\($0 - score) to go" : "Reached \($0)" }
        case .lowestWins:  rules.target.map { "game ends at \($0)" }
        }
        return DisplayScore(primary: "\(score)", secondary: secondary)
    }
}
