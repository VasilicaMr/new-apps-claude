import Foundation

struct DartsConfig: Codable, Sendable {
    var startingScore: Int? = nil
    var doubleIn: Bool = false
    var doubleOut: Bool = true
}

final class DartsScoringEngine: ScoringEngine {
    let sport: SportType = .darts
    let variant: String

    static let dartsPerTurn = 3
    private let shanghaiRounds = 7

    init(variant: String) {
        self.variant = variant
    }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        switch variant {
        case "Cricket":          return processCricket(entry: entry, for: playerID, in: session)
        case "Around The Clock": return processAroundTheClock(entry: entry, for: playerID, in: session)
        case "Shanghai":         return processShanghai(entry: entry, for: playerID, in: session)
        default:                 return processCountdown(entry: entry, for: playerID, in: session)
        }
    }

    func isGameOver(_ session: GameSession) -> Bool {
        session.winnerID != nil
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let entries = session.allEntries(for: playerID)
        switch variant {
        case "Cricket":
            let state = buildCricketState(session: session, playerID: playerID, newEntry: nil)
            return DisplayScore(primary: "\(state.points)", detail: marksDetail(state.marks))
        case "Around The Clock":
            let target = clockTarget(entries)
            return DisplayScore(primary: target > 21 ? "Done" : clockLabel(target), secondary: "Target")
        case "Shanghai":
            let total = shanghaiTotal(entries)
            return DisplayScore(primary: "\(total)", secondary: "Round \(min(turns(entries).completed + 1, shanghaiRounds))")
        default:
            let state = countdownState(entries, start: startingScore(session))
            let turnInfo = state.dartsInTurn > 0 ? "This turn: \(state.turnPoints)" : nil
            return DisplayScore(primary: "\(state.remaining)", secondary: turnInfo)
        }
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let entries = session.allEntries(for: playerID)
        let dart = turns(entries).inProgress + 1
        switch variant {
        case "Around The Clock":
            return EntryContext(prompt: "Dart \(dart)/3 · aim for \(clockLabel(clockTarget(entries)))")
        case "Shanghai":
            let t = turns(entries)
            let finished = t.completed >= shanghaiRounds
            return EntryContext(
                prompt: finished ? "All rounds thrown" : "Round \(t.completed + 1) · Dart \(dart)/3 · aim for \(t.completed + 1)s",
                isPlayerFinished: finished
            )
        case "Cricket":
            return EntryContext(prompt: "Dart \(dart)/3")
        default:
            let state = countdownState(entries, start: startingScore(session))
            return EntryContext(prompt: "Dart \(dart)/3 · \(state.remaining) left")
        }
    }

    // MARK: - Turns

    /// Darts are grouped into turns of three. A bust marker ends the turn early.
    private func turns(_ entries: [ScoreEntry]) -> (completed: Int, inProgress: Int) {
        var completed = 0
        var current = 0
        for e in entries {
            current += 1
            if isBustMarker(e) || current == Self.dartsPerTurn {
                completed += 1
                current = 0
            }
        }
        return (completed, current)
    }

    private func isBustMarker(_ e: ScoreEntry) -> Bool {
        e.metadata?["bust"] == "true"
    }

    // MARK: - Countdown (501/301/701)

    private func startingScore(_ session: GameSession) -> Int {
        session.config(as: DartsConfig.self)?.startingScore ?? Int(variant) ?? 501
    }

    private struct CountdownState {
        var remaining: Int
        var dartsInTurn: Int
        var turnPoints: Int
    }

    /// A busted turn scores nothing: the player returns to their score at the start of that turn.
    private func countdownState(_ entries: [ScoreEntry], start: Int) -> CountdownState {
        var banked = start
        var turn: [ScoreEntry] = []
        for e in entries {
            turn.append(e)
            if isBustMarker(e) {
                turn = []
            } else if turn.count == Self.dartsPerTurn {
                banked -= turn.reduce(0) { $0 + $1.value }
                turn = []
            }
        }
        let turnPoints = turn.reduce(0) { $0 + $1.value }
        return CountdownState(remaining: banked - turnPoints, dartsInTurn: turn.count, turnPoints: turnPoints)
    }

    private func processCountdown(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: DartsConfig.self) ?? DartsConfig()
        let state = countdownState(session.allEntries(for: playerID), start: startingScore(session))
        let newScore = state.remaining - entry.value
        let isDouble = entry.metadata?["multiplier"] == "2"
        let turnStart = state.remaining + state.turnPoints

        let needsDoubleFinish = config.doubleOut
        if newScore < 0 || (needsDoubleFinish && newScore == 1) || (newScore == 0 && needsDoubleFinish && !isDouble) {
            let reason = newScore == 0 ? "Bust — must finish on a double" : "Bust"
            return ScoringResult(
                displayScore: DisplayScore(primary: "\(turnStart)", secondary: "BUST"),
                isBust: true,
                turnAdvances: true,
                notes: "\(reason). Score returns to \(turnStart)."
            )
        }

        if newScore == 0 {
            return ScoringResult(
                displayScore: DisplayScore(primary: "0", secondary: "WINNER!"),
                isGameOver: true,
                winner: playerID,
                turnAdvances: false
            )
        }

        return ScoringResult(
            displayScore: DisplayScore(primary: "\(newScore)"),
            turnAdvances: state.dartsInTurn + 1 >= Self.dartsPerTurn
        )
    }

    // MARK: - Around The Clock (1 → 20 → Bull)

    private func segmentNumber(_ e: ScoreEntry) -> Int {
        let seg = e.metadata?["segment"] ?? "0"
        return seg == "bull" ? 25 : (Int(seg) ?? 0)
    }

    /// 1…20, then 21 means Bull, 22 means finished.
    private func clockTarget(_ entries: [ScoreEntry]) -> Int {
        var target = 1
        for e in entries where target <= 21 {
            let hit = segmentNumber(e)
            if (target <= 20 && hit == target) || (target == 21 && hit == 25) {
                target += 1
            }
        }
        return target
    }

    private func clockLabel(_ target: Int) -> String {
        target == 21 ? "Bull" : "\(target)"
    }

    private func processAroundTheClock(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let entries = session.allEntries(for: playerID) + [entry]
        let target = clockTarget(entries)
        let finished = target > 21
        return ScoringResult(
            displayScore: DisplayScore(primary: finished ? "Done" : clockLabel(target), secondary: "Target"),
            isGameOver: finished,
            winner: finished ? playerID : nil,
            turnAdvances: turns(entries).inProgress == 0
        )
    }

    // MARK: - Shanghai (7 rounds, only the round's number scores)

    private func shanghaiTotal(_ entries: [ScoreEntry]) -> Int {
        var total = 0
        var dartIndex = 0
        for e in entries {
            let round = dartIndex / Self.dartsPerTurn + 1
            if segmentNumber(e) == round { total += e.value }
            dartIndex += 1
        }
        return total
    }

    private func processShanghai(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let previous = session.allEntries(for: playerID)
        guard turns(previous).completed < shanghaiRounds else {
            return .rejected("All \(shanghaiRounds) rounds already thrown.")
        }
        let entries = previous + [entry]
        let round = (entries.count - 1) / Self.dartsPerTurn + 1
        let turnDarts = entries.suffix(entries.count - (round - 1) * Self.dartsPerTurn)
        let multipliers = Set(turnDarts.filter { segmentNumber($0) == round }.compactMap { $0.metadata?["multiplier"] })
        let isShanghai = multipliers.isSuperset(of: ["1", "2", "3"])
        let total = shanghaiTotal(entries)

        if isShanghai {
            return ScoringResult(
                displayScore: DisplayScore(primary: "\(total)", secondary: "SHANGHAI!"),
                isGameOver: true,
                winner: playerID,
                turnAdvances: false
            )
        }

        var totals: [UUID: Int] = [:]
        for p in session.players {
            totals[p.id] = shanghaiTotal(p.id == playerID ? entries : session.allEntries(for: p.id))
        }
        return fixedLengthResult(
            display: DisplayScore(primary: "\(total)", secondary: "Round \(round)"),
            session: session,
            playerID: playerID,
            entry: entry,
            isFinished: { _, count in count >= self.shanghaiRounds * Self.dartsPerTurn },
            totals: totals,
            turnAdvances: entries.count % Self.dartsPerTurn == 0
        )
    }

    // MARK: - Cricket

    private func processCricket(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let full = buildFullCricketState(session: session, playerID: playerID, newEntry: entry)
        let state = full.active
        let allClosed = cricketNumbers.allSatisfy { (state.marks[$0] ?? 0) >= 3 }
        let score = state.points
        let dartsThrown = session.allEntries(for: playerID).count + 1

        if allClosed && !full.opponents.contains(where: { $0.points > score }) {
            return ScoringResult(
                displayScore: DisplayScore(primary: "\(score)", secondary: "All closed!"),
                isGameOver: true,
                winner: playerID,
                turnAdvances: false
            )
        }
        return ScoringResult(
            displayScore: DisplayScore(primary: "\(score)", detail: marksDetail(state.marks)),
            turnAdvances: dartsThrown % Self.dartsPerTurn == 0
        )
    }

    private let cricketNumbers = [15, 16, 17, 18, 19, 20, 25]

    private struct CricketState {
        var marks: [Int: Int] = [:]
        var points: Int = 0
    }

    private struct FullCricketState {
        var active: CricketState
        var opponents: [CricketState]
    }

    /// Rebuilds cricket state for ALL players chronologically so that
    /// scoring points correctly requires the opponent to NOT have closed the number.
    private func buildFullCricketState(
        session: GameSession,
        playerID: UUID,
        newEntry: ScoreEntry?
    ) -> FullCricketState {
        var allStates: [UUID: CricketState] = [:]
        for p in session.players { allStates[p.id] = CricketState() }

        for (pid, e) in session.chronologicalEntries {
            applyEntry(e, for: pid, allStates: &allStates)
        }
        if let newEntry {
            applyEntry(newEntry, for: playerID, allStates: &allStates)
        }

        let active = allStates[playerID] ?? CricketState()
        let opponents = session.players.filter { $0.id != playerID }.compactMap { allStates[$0.id] }
        return FullCricketState(active: active, opponents: opponents)
    }

    private func applyEntry(_ entry: ScoreEntry, for playerID: UUID, allStates: inout [UUID: CricketState]) {
        let num = segmentNumber(entry)
        let mult = Int(entry.metadata?["multiplier"] ?? "1") ?? 1
        guard cricketNumbers.contains(num) else { return }
        let before = allStates[playerID]?.marks[num] ?? 0
        allStates[playerID]?.marks[num] = min(before + mult, 3)
        let overflow = (before + mult) - max(before, 3)
        // Only score if opponent(s) haven't closed this number yet
        if overflow > 0 {
            let opponentsAllClosed = allStates.filter { $0.key != playerID }
                .allSatisfy { ($0.value.marks[num] ?? 0) >= 3 }
            if !opponentsAllClosed {
                allStates[playerID]?.points += num * overflow
            }
        }
    }

    private func buildCricketState(session: GameSession, playerID: UUID, newEntry: ScoreEntry?) -> CricketState {
        buildFullCricketState(session: session, playerID: playerID, newEntry: newEntry).active
    }

    private func marksDetail(_ marks: [Int: Int]) -> String {
        cricketNumbers.map { n in
            let m = marks[n] ?? 0
            let label = n == 25 ? "B" : "\(n)"
            let indicator = m == 0 ? "○" : m == 1 ? "∕" : m == 2 ? "⦸" : "⊗"
            return "\(label):\(indicator)"
        }.joined(separator: " ")
    }
}
