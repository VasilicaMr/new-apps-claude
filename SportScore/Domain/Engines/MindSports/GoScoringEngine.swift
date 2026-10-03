import Foundation

struct GoConfig: Codable, Sendable {
    var komi: Double = 6.5
    var handicap: Int = 0
}

/// Entries: label "capture" (stones captured, value N) and label "territory"
/// (final territory count, entered once per player at the end). The first
/// player is Black; White (second player) receives komi. The game ends once
/// both players have entered territory: score = territory + captures (+ komi).
final class GoScoringEngine: ScoringEngine {
    let sport: SportType = .go
    let boardSize: String
    init(boardSize: String) { self.boardSize = boardSize }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let mine = session.allEntries(for: playerID)
        if entry.label == "territory" && mine.contains(where: { $0.label == "territory" }) {
            return .rejected("Territory already entered for this player. Undo it to change.")
        }
        guard entry.value >= 0 else { return .rejected("Enter a positive number.") }

        let entries: (UUID) -> [ScoreEntry] = { id in
            session.allEntries(for: id) + (id == playerID ? [entry] : [])
        }
        let bothCounted = session.players.allSatisfy { p in entries(p.id).contains { $0.label == "territory" } }
        var totals: [UUID: Double] = [:]
        for p in session.players { totals[p.id] = score(entries(p.id), isWhite: isWhite(p.id, session), session: session) }

        let my = totals[playerID] ?? 0
        var winner: UUID? = nil
        if bothCounted, let best = totals.values.max() {
            let leaders = totals.filter { $0.value == best }
            winner = leaders.count == 1 ? leaders.first?.key : nil
        }
        return ScoringResult(
            displayScore: DisplayScore(primary: format(my), secondary: bothCounted ? "Final" : "Captures \(captures(entries(playerID)))"),
            isGameOver: bothCounted,
            winner: winner,
            turnAdvances: entry.label == "territory"
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let entries = session.allEntries(for: playerID)
        let white = isWhite(playerID, session)
        let color = white ? "White" : "Black"
        if entries.contains(where: { $0.label == "territory" }) {
            return DisplayScore(primary: format(score(entries, isWhite: white, session: session)), secondary: "\(color) · final")
        }
        let komiNote = white ? " + \(format(komi(session))) komi" : ""
        return DisplayScore(primary: "\(captures(entries))", secondary: "\(color) · captures\(komiNote)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let counted = session.allEntries(for: playerID).contains { $0.label == "territory" }
        return EntryContext(
            prompt: counted ? "Territory entered — waiting for opponent" : "\(boardSize) · log captures, then final territory",
            isPlayerFinished: counted
        )
    }

    private func komi(_ session: GameSession) -> Double {
        (session.config(as: GoConfig.self) ?? GoConfig()).komi
    }

    private func isWhite(_ playerID: UUID, _ session: GameSession) -> Bool {
        session.players.count > 1 && session.players.last?.id == playerID
    }

    private func captures(_ entries: [ScoreEntry]) -> Int {
        entries.filter { $0.label != "territory" }.reduce(0) { $0 + $1.value }
    }

    private func score(_ entries: [ScoreEntry], isWhite: Bool, session: GameSession) -> Double {
        let territory = entries.filter { $0.label == "territory" }.reduce(0) { $0 + $1.value }
        return Double(territory + captures(entries)) + (isWhite ? komi(session) : 0)
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
