import Foundation

struct ChessConfig: Codable, Sendable {
    var gamesInMatch: Int = 4
    var trackELO: Bool = false
    var timeFormat: String = "Rapid"
}

/// Each entry is one finished game, recorded from the point of view of the
/// player it was entered for: 2 = win, 1 = draw, 0 = loss. The opponent's
/// result is implied, so a game only needs to be entered once.
final class ChessScoringEngine: ScoringEngine {
    let sport: SportType = .chess

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        guard (0...2).contains(entry.value) else { return .rejected("Choose Win, Draw or Loss.") }
        let config = session.config(as: ChessConfig.self) ?? ChessConfig()
        let games = session.chronologicalEntries.map { ($0.playerID, $0.entry.value) } + [(playerID, entry.value)]
        let points = matchPoints(games, session: session)
        let my = points[playerID] ?? 0
        let opponentID = session.opponent(of: playerID)
        let op = opponentID.flatMap { points[$0] } ?? 0

        // Match ends when all games are played or someone can no longer be caught.
        let remaining = Double(config.gamesInMatch - games.count)
        let isMatchEnd = remaining <= 0 || abs(my - op) > remaining
        let winner: UUID? = !isMatchEnd || my == op ? nil : (my > op ? playerID : opponentID)

        return ScoringResult(
            displayScore: DisplayScore(
                primary: format(my),
                secondary: "Game \(games.count)/\(config.gamesInMatch)"
            ),
            isGameOver: isMatchEnd,
            winner: winner
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        session.winnerID != nil || !session.isActive
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let config = session.config(as: ChessConfig.self) ?? ChessConfig()
        let games = session.chronologicalEntries.map { ($0.playerID, $0.entry.value) }
        let pts = matchPoints(games, session: session)[playerID] ?? 0
        return DisplayScore(primary: format(pts), secondary: "Games \(games.count)/\(config.gamesInMatch)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: ChessConfig.self) ?? ChessConfig()
        let played = session.chronologicalEntries.count
        return EntryContext(prompt: "Game \(played + 1) of \(config.gamesInMatch) — result for this player")
    }

    private func matchPoints(_ games: [(UUID, Int)], session: GameSession) -> [UUID: Double] {
        var pts: [UUID: Double] = [:]
        for p in session.players { pts[p.id] = 0 }
        for (pid, value) in games {
            pts[pid, default: 0] += Double(value) * 0.5
            if let opp = session.opponent(of: pid) {
                pts[opp, default: 0] += Double(2 - value) * 0.5
            }
        }
        return pts
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
