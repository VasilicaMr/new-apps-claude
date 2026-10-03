import Foundation

struct MahjongConfig: Codable, Sendable {
    var startingPoints: Int = 30000
}

final class MahjongScoringEngine: ScoringEngine {
    let sport: SportType = .mahjong
    let variant: String
    init(variant: String) { self.variant = variant }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: MahjongConfig.self) ?? MahjongConfig()
        let delta = entry.value
        let total = config.startingPoints + session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + delta
        let handCount = session.frames(for: playerID).count + 1

        return ScoringResult(
            displayScore: DisplayScore(
                primary: "\(total)",
                secondary: "Hand \(handCount)"
            )
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { false }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        EntryContext(prompt: "Hand result · use − for points paid", allowsNegative: true)
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let config = session.config(as: MahjongConfig.self) ?? MahjongConfig()
        let total = config.startingPoints + session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
