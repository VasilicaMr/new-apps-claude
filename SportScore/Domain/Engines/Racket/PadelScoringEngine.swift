import Foundation

final class PadelScoringEngine: ScoringEngine {
    let sport: SportType = .padel
    private let tennisEngine = TennisScoringEngine(variant: "Best of 3")

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        tennisEngine.process(entry: entry, for: playerID, in: session)
    }

    func isGameOver(_ session: GameSession) -> Bool {
        tennisEngine.isGameOver(session)
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        tennisEngine.currentScore(for: playerID, in: session)
    }
}
