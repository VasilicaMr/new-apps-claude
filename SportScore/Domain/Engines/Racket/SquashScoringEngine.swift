import Foundation

final class SquashScoringEngine: ScoringEngine {
    let sport: SportType = .squash
    let variant: String
    init(variant: String) { self.variant = variant }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let target = variant == "HiHo" ? 9 : 11
        let gamesNeeded = 3  // best of 5
        var state = buildMatchState(session, target: target)
        let oppID = session.players.first { $0.id != playerID }?.id

        state.currentPoints[playerID, default: 0] += entry.value
        let myPts = state.currentPoints[playerID] ?? 0
        let opPts = oppID.map { state.currentPoints[$0] ?? 0 } ?? 0
        let myGames = state.gamesWon[playerID] ?? 0
        let opGames = oppID.map { state.gamesWon[$0] ?? 0 } ?? 0

        if myPts >= target && myPts - opPts >= 2 {
            let newMyGames = myGames + 1
            let isWin = newMyGames >= gamesNeeded
            return ScoringResult(
                displayScore: DisplayScore(
                    primary: "0-0",
                    secondary: "Games \(newMyGames)-\(opGames)"
                ),
                isGameOver: isWin,
                winner: isWin ? playerID : nil,
                notes: "Game won"
            )
        }

        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(myPts)-\(opPts)",
                secondary: "Games \(myGames)-\(opGames)"
            )
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { session.winnerID != nil }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let target = variant == "HiHo" ? 9 : 11
        let state = buildMatchState(session, target: target)
        let pts = state.currentPoints[playerID] ?? 0
        let games = state.gamesWon[playerID] ?? 0
        return DisplayScore(primary: "\(pts)-\(target)", secondary: "Games: \(games)")
    }

    // MARK: - State machine

    private struct MatchState {
        var gamesWon: [UUID: Int] = [:]
        var currentPoints: [UUID: Int] = [:]
    }

    private func buildMatchState(_ session: GameSession, target: Int) -> MatchState {
        var state = MatchState()
        for p in session.players {
            state.gamesWon[p.id] = 0
            state.currentPoints[p.id] = 0
        }
        for frame in session.frames.sorted(by: { $0.timestamp < $1.timestamp }) {
            let pts = frame.entries.reduce(0) { $0 + $1.value }
            state.currentPoints[frame.playerID, default: 0] += pts
            let myPts = state.currentPoints[frame.playerID] ?? 0
            let oppID = session.players.first { $0.id != frame.playerID }?.id
            let opPts = oppID.map { state.currentPoints[$0] ?? 0 } ?? 0
            if myPts >= target && myPts - opPts >= 2 {
                state.gamesWon[frame.playerID, default: 0] += 1
                state.currentPoints[frame.playerID] = 0
                if let opp = oppID { state.currentPoints[opp] = 0 }
            }
        }
        return state
    }
}
