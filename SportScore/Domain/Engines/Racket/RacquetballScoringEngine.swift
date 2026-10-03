import Foundation

final class RacquetballScoringEngine: ScoringEngine {
    let sport: SportType = .racquetball

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        var state = buildMatchState(session)
        let oppID = session.players.first { $0.id != playerID }?.id
        let myGames = state.gamesWon[playerID] ?? 0
        let opGames = oppID.map { state.gamesWon[$0] ?? 0 } ?? 0
        let isTiebreak = myGames + opGames >= 2
        let target = isTiebreak ? 11 : 15

        state.currentPoints[playerID, default: 0] += entry.value
        let myPts = state.currentPoints[playerID] ?? 0
        let opPts = oppID.map { state.currentPoints[$0] ?? 0 } ?? 0

        // Racquetball: no win-by-2 requirement; first to reach target wins
        if myPts >= target {
            let newMyGames = myGames + 1
            let isWin = newMyGames >= 2
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
        let state = buildMatchState(session)
        let pts = state.currentPoints[playerID] ?? 0
        let games = state.gamesWon[playerID] ?? 0
        return DisplayScore(primary: "\(pts)", secondary: "Games: \(games)")
    }

    // MARK: - State machine

    private struct MatchState {
        var gamesWon: [UUID: Int] = [:]
        var currentPoints: [UUID: Int] = [:]
    }

    private func buildMatchState(_ session: GameSession) -> MatchState {
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
            let totalGames = (state.gamesWon[frame.playerID] ?? 0) + (oppID.map { state.gamesWon[$0] ?? 0 } ?? 0)
            let target = totalGames >= 2 ? 11 : 15
            if myPts >= target {
                state.gamesWon[frame.playerID, default: 0] += 1
                state.currentPoints[frame.playerID] = 0
                if let opp = oppID { state.currentPoints[opp] = 0 }
            }
        }
        return state
    }
}
