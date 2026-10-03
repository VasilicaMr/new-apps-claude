import Foundation

final class CandlepinScoringEngine: FrameBowlingEngine {
    let sport: SportType = .bowlingCandlepin
    let scorer = BowlingScorer(ballsPerFrame: 3)
}
