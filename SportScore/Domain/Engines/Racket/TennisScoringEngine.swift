import Foundation

struct TennisConfig: Codable, Sendable {
    var setsInMatch: Int = 3
    var noAd: Bool = false
    var matchTiebreak: Bool = true
}

enum TennisPoint: Int, Codable, Sendable {
    case love = 0, fifteen = 1, thirty = 2, forty = 3, advantage = 4
    var display: String {
        switch self { case .love: "0"; case .fifteen: "15"; case .thirty: "30"; case .forty: "40"; case .advantage: "Ad" }
    }
}

struct TennisState: Sendable {
    var setsWon: [UUID: Int] = [:]
    var gamesWon: [UUID: Int] = [:]
    var points: [UUID: TennisPoint] = [:]
    var inTiebreak: Bool = false
    var tiebreakPoints: [UUID: Int] = [:]
}

final class TennisScoringEngine: ScoringEngine {
    let sport: SportType = .tennis
    let variant: String?

    init(variant: String? = nil) { self.variant = variant }

    private func matchConfig(_ session: GameSession) -> TennisConfig {
        var config = session.config(as: TennisConfig.self) ?? TennisConfig()
        if session.configJSON == nil, let sets = bestOf(variant) { config.setsInMatch = sets }
        return config
    }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        var state = buildState(session: session)
        let opponentID = session.players.first { $0.id != playerID }?.id

        applyPoint(to: &state, scorer: playerID, opponent: opponentID, session: session, config: matchConfig(session))

        let setsWon = state.setsWon[playerID] ?? 0
        let config = matchConfig(session)
        let setsNeeded = (config.setsInMatch / 2) + 1
        let isWin = setsWon >= setsNeeded

        let scoreDisplay = scoreString(state: state, playerID: playerID, opponentID: opponentID)
        return ScoringResult(
            displayScore: DisplayScore(primary: scoreDisplay),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = matchConfig(session)
        let setsNeeded = (config.setsInMatch / 2) + 1
        let state = buildState(session: session)
        return session.players.contains { (state.setsWon[$0.id] ?? 0) >= setsNeeded }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let state = buildState(session: session)
        let opponentID = session.players.first { $0.id != playerID }?.id
        return DisplayScore(primary: scoreString(state: state, playerID: playerID, opponentID: opponentID))
    }

    // MARK: - State reconstruction

    private func buildState(session: GameSession) -> TennisState {
        var state = TennisState()
        for player in session.players {
            state.setsWon[player.id] = 0
            state.gamesWon[player.id] = 0
            state.points[player.id] = .love
            state.tiebreakPoints[player.id] = 0
        }
        let config = matchConfig(session)
        let opponentMap: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: session.players.compactMap { p in
                session.players.first { $0.id != p.id }.map { (p.id, $0.id) }
            }
        )
        // Use frame.playerID (reliable) rather than metadata["scorerID"] (fragile)
        for frame in session.frames.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let opponentID = opponentMap[frame.playerID] else { continue }
            for _ in frame.entries {
                applyPoint(to: &state, scorer: frame.playerID, opponent: opponentID, session: session, config: config)
            }
        }
        return state
    }

    private func applyPoint(to state: inout TennisState, scorer: UUID, opponent: UUID?, session: GameSession, config: TennisConfig) {
        guard let opp = opponent else { return }

        if state.inTiebreak {
            state.tiebreakPoints[scorer, default: 0] += 1
            let sp = state.tiebreakPoints[scorer] ?? 0
            let op = state.tiebreakPoints[opp] ?? 0
            if sp >= 7 && sp - op >= 2 {
                state.setsWon[scorer, default: 0] += 1
                state.gamesWon[scorer] = 0
                state.gamesWon[opp] = 0
                state.tiebreakPoints[scorer] = 0
                state.tiebreakPoints[opp] = 0
                state.inTiebreak = false
            }
            return
        }

        let sp = state.points[scorer] ?? .love
        let op = state.points[opp] ?? .love

        if sp == .forty && op == .advantage {
            state.points[scorer] = .forty
            state.points[opp] = .forty
        } else if sp == .forty && op == .forty {
            if config.noAd {
                winGame(&state, scorer: scorer, opp: opp, session: session)
            } else {
                state.points[scorer] = .advantage
            }
        } else if sp == .advantage {
            winGame(&state, scorer: scorer, opp: opp, session: session)
        } else if sp == .forty {
            winGame(&state, scorer: scorer, opp: opp, session: session)
        } else {
            state.points[scorer] = TennisPoint(rawValue: (sp.rawValue + 1)) ?? .love
        }
    }

    private func winGame(_ state: inout TennisState, scorer: UUID, opp: UUID, session: GameSession) {
        state.gamesWon[scorer, default: 0] += 1
        state.points[scorer] = .love
        state.points[opp] = .love
        let sg = state.gamesWon[scorer] ?? 0
        let og = state.gamesWon[opp] ?? 0
        if sg >= 6 && sg - og >= 2 {
            state.setsWon[scorer, default: 0] += 1
            state.gamesWon[scorer] = 0
            state.gamesWon[opp] = 0
        } else if sg == 6 && og == 6 {
            state.inTiebreak = true
        }
    }

    private func scoreString(state: TennisState, playerID: UUID, opponentID: UUID?) -> String {
        guard let opp = opponentID else { return "0" }
        let sets = "\(state.setsWon[playerID] ?? 0)-\(state.setsWon[opp] ?? 0)"
        let games = "\(state.gamesWon[playerID] ?? 0)-\(state.gamesWon[opp] ?? 0)"
        let pts = state.inTiebreak
            ? "\(state.tiebreakPoints[playerID] ?? 0)-\(state.tiebreakPoints[opp] ?? 0)"
            : "\((state.points[playerID] ?? .love).display)-\((state.points[opp] ?? .love).display)"
        return "\(pts) | \(games) | \(sets)"
    }
}
