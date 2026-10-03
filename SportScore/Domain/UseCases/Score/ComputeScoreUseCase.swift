import Foundation

struct ComputeScoreUseCase {
    let engineFactory: ScoringEngineFactory

    func execute(session: GameSession, newEntry: ScoreEntry, for playerID: UUID) -> ScoringResult {
        let engine = engineFactory.engine(for: session.sport, variant: session.variant)
        return engine.process(entry: newEntry, for: playerID, in: session)
    }
}
