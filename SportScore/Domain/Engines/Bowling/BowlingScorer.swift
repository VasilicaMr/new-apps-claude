import Foundation

/// Frame-by-frame bowling scorer shared by ten-pin (2 balls per frame)
/// and candlepin/duckpin (3 balls per frame). Strike = all pins on ball 1
/// (+ next two balls), spare = all pins by ball 2 (+ next ball).
struct BowlingScorer: Sendable {
    let ballsPerFrame: Int
    let pins: Int = 10
    let frameCount: Int = 10

    struct State: Sendable {
        var total: Int = 0
        /// 1-based frame the next ball belongs to (capped at 10).
        var frame: Int = 1
        /// 1-based ball number within that frame.
        var ball: Int = 1
        var pinsStanding: Int = 10
        var isComplete: Bool = false
    }

    func state(_ balls: [Int]) -> State {
        var s = State(pinsStanding: pins)
        var i = 0

        func bonus(from start: Int, count: Int) -> Int {
            balls.dropFirst(start).prefix(count).reduce(0, +)
        }

        for f in 0..<(frameCount - 1) {
            s.frame = f + 1
            guard i < balls.count else { s.ball = 1; s.pinsStanding = pins; return s }
            let b1 = balls[i]
            if b1 >= pins {
                s.total += pins + bonus(from: i + 1, count: 2)
                i += 1
                continue
            }
            guard i + 1 < balls.count else { s.ball = 2; s.pinsStanding = pins - b1; return s }
            let b2 = balls[i + 1]
            if b1 + b2 >= pins {
                s.total += pins + bonus(from: i + 2, count: 1)
                i += 2
                continue
            }
            if ballsPerFrame == 2 {
                s.total += b1 + b2
                i += 2
                continue
            }
            guard i + 2 < balls.count else { s.ball = 3; s.pinsStanding = pins - b1 - b2; return s }
            s.total += b1 + b2 + balls[i + 2]
            i += 3
        }

        // Tenth frame: pins reset after a strike or spare; a mark earns extra balls.
        s.frame = frameCount
        let last = Array(balls.dropFirst(i).prefix(3))
        var standing = pins
        var markEarned = false
        for (n, b) in last.enumerated() {
            standing -= b
            if standing <= 0 {
                if n < 2 { markEarned = true }
                standing = pins
            }
        }
        let allowed = ballsPerFrame == 3 || markEarned ? 3 : 2
        s.total += last.reduce(0, +)
        s.isComplete = last.count >= allowed
        s.ball = min(last.count + 1, allowed)
        s.pinsStanding = standing
        return s
    }
}

/// Shared engine behaviour for frame-based bowling variants.
protocol FrameBowlingEngine: ScoringEngine {
    var scorer: BowlingScorer { get }
}

extension FrameBowlingEngine {
    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let previous = session.allEntries(for: playerID).map(\.value)
        let before = scorer.state(previous)
        if before.isComplete {
            return .rejected("All 10 frames already bowled.")
        }
        guard entry.value >= 0, entry.value <= before.pinsStanding else {
            return .rejected("Only \(before.pinsStanding) pin\(before.pinsStanding == 1 ? "" : "s") standing.")
        }
        let after = scorer.state(previous + [entry.value])
        let frameEnded = after.isComplete || after.frame > before.frame

        var totals: [UUID: Int] = [:]
        for p in session.players {
            let balls = session.allEntries(for: p.id).map(\.value) + (p.id == playerID ? [entry.value] : [])
            totals[p.id] = scorer.state(balls).total
        }
        return fixedLengthResult(
            display: DisplayScore(
                primary: "\(after.total)",
                secondary: "Frame \(after.frame)",
                detail: after.total == 300 && after.isComplete ? "Perfect game!" : nil
            ),
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { id, _ in
                let balls = session.allEntries(for: id).map(\.value) + (id == playerID ? [entry.value] : [])
                return scorer.state(balls).isComplete
            },
            totals: totals,
            turnAdvances: frameEnded
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        session.players.allSatisfy { scorer.state(session.allEntries(for: $0.id).map(\.value)).isComplete }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let s = scorer.state(session.allEntries(for: playerID).map(\.value))
        return DisplayScore(primary: "\(s.total)", secondary: s.isComplete ? "Final" : "Frame \(s.frame)")
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let s = scorer.state(session.allEntries(for: playerID).map(\.value))
        if s.isComplete { return EntryContext(prompt: "Game complete", maxValue: 0, isPlayerFinished: true) }
        return EntryContext(prompt: "Frame \(s.frame) · Ball \(s.ball)", maxValue: s.pinsStanding)
    }
}
