import Foundation

final class DuckpinScoringEngine: FrameBowlingEngine {
    let sport: SportType = .bowlingDuckpin
    let scorer = BowlingScorer(ballsPerFrame: 3)
}
