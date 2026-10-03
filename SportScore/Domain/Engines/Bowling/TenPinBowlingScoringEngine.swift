import Foundation

final class TenPinBowlingScoringEngine: FrameBowlingEngine {
    let sport: SportType = .bowlingTenPin
    let scorer = BowlingScorer(ballsPerFrame: 2)
}
