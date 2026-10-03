import Foundation

struct BackgammonConfig: Codable, Sendable {
    var matchLength: Int = 7
    var crawfordRule: Bool = true
}

final class BackgammonScoringEngine: ScoringEngine {
    let sport: SportType = .backgammon

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: BackgammonConfig.self) ?? BackgammonConfig()
        let cubeValue = Int(entry.metadata?["cubeValue"] ?? "1") ?? 1
        let pointsEarned = entry.value * cubeValue
        let totalPoints = session.allEntries(for: playerID).reduce(0) { accum, e in
            let cv = Int(e.metadata?["cubeValue"] ?? "1") ?? 1
            return accum + e.value * cv
        } + pointsEarned
        let isWin = totalPoints >= config.matchLength

        let resultLabel = entry.value == 3 ? "Backgammon" : entry.value == 2 ? "Gammon" : "Win"
        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(totalPoints)",
                secondary: "\(totalPoints)/\(config.matchLength)",
                detail: entry.value > 0 ? "\(resultLabel) ×\(cubeValue)" : nil
            ),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: BackgammonConfig.self) ?? BackgammonConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { accum, e in
                accum + e.value * (Int(e.metadata?["cubeValue"] ?? "1") ?? 1)
            } >= config.matchLength
        }
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: BackgammonConfig.self) ?? BackgammonConfig()
        return EntryContext(prompt: "Match to \(config.matchLength) · set the cube, then record the game")
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { accum, e in
            accum + e.value * (Int(e.metadata?["cubeValue"] ?? "1") ?? 1)
        }
        return DisplayScore(primary: "\(total)")
    }
}
