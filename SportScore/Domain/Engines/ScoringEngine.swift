import Foundation

// MARK: - Display types

struct DisplayScore: Hashable, Sendable {
    var primary: String
    var secondary: String?
    var detail: String?

    static let zero = DisplayScore(primary: "0")
}

struct ScoringResult: Sendable {
    var displayScore: DisplayScore
    /// The entry is recorded as a bust marker and the player's turn ends (e.g. darts).
    var isBust: Bool = false
    var isGameOver: Bool = false
    var winner: UUID? = nil
    var turnAdvances: Bool = true
    var notes: String? = nil
    /// The entry is invalid and must not be recorded. The message is shown to the user.
    var rejection: String? = nil

    static func rejected(_ message: String) -> ScoringResult {
        ScoringResult(displayScore: .zero, turnAdvances: false, rejection: message)
    }
}

/// Live hints the entry UI uses to constrain and label input for the active player.
struct EntryContext: Sendable {
    var prompt: String? = nil
    var maxValue: Int? = nil
    var allowsNegative: Bool = false
    /// The player has nothing left to enter (e.g. all frames bowled); turn rotation skips them.
    var isPlayerFinished: Bool = false
}

// MARK: - Protocol

protocol ScoringEngine: Sendable {
    var sport: SportType { get }
    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult
    func isGameOver(_ session: GameSession) -> Bool
    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore
    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext
}

extension ScoringEngine {
    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext { EntryContext() }
}

// MARK: - Shared helpers

enum ScoreRanking {
    case highest, lowest
}

/// Winner of a fixed-length game once every player has finished. Returns nil on a tie.
func rankedWinner(_ totals: [UUID: Int], ranking: ScoreRanking) -> UUID? {
    let best = ranking == .highest ? totals.values.max() : totals.values.min()
    let leaders = totals.filter { $0.value == best }
    return leaders.count == 1 ? leaders.first?.key : nil
}

extension GameSession {
    /// Points for each player, including an entry that has not been recorded yet.
    func totals(adding entry: ScoreEntry? = nil, for playerID: UUID? = nil) -> [UUID: Int] {
        var totals: [UUID: Int] = [:]
        for p in players {
            totals[p.id] = allEntries(for: p.id).reduce(0) { $0 + $1.value }
        }
        if let entry, let playerID { totals[playerID, default: 0] += entry.value }
        return totals
    }

    /// Entry counts for each player, including an entry that has not been recorded yet.
    func entryCounts(addingFor playerID: UUID? = nil) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for p in players { counts[p.id] = allEntries(for: p.id).count }
        if let playerID { counts[playerID, default: 0] += 1 }
        return counts
    }

    /// All entries across players in the order they were recorded.
    var chronologicalEntries: [(playerID: UUID, entry: ScoreEntry)] {
        frames.sorted { $0.timestamp < $1.timestamp }
            .flatMap { frame in frame.entries.map { (frame.playerID, $0) } }
    }

    func opponent(of playerID: UUID) -> UUID? {
        players.first { $0.id != playerID }?.id
    }
}

/// Shared result for games where every player takes a fixed number of turns
/// (archery ends, bowling frames, curling ends…). The game only ends once
/// *every* player has finished, so nobody is locked out of their last turns.
func fixedLengthResult(
    display: DisplayScore,
    session: GameSession,
    playerID: UUID,
    entry: ScoreEntry,
    isFinished: (UUID, Int) -> Bool,
    ranking: ScoreRanking = .highest,
    totals: [UUID: Int]? = nil,
    turnAdvances: Bool = true
) -> ScoringResult {
    let counts = session.entryCounts(addingFor: playerID)
    let allDone = session.players.allSatisfy { isFinished($0.id, counts[$0.id] ?? 0) }
    let finalTotals = totals ?? session.totals(adding: entry, for: playerID)
    return ScoringResult(
        displayScore: display,
        isGameOver: allDone,
        winner: allDone ? rankedWinner(finalTotals, ranking: ranking) : nil,
        turnAdvances: turnAdvances
    )
}

/// Parses variants such as "Best of 5" into 5.
func bestOf(_ variant: String?) -> Int? {
    guard let variant, variant.hasPrefix("Best of ") else { return nil }
    return Int(variant.dropFirst("Best of ".count))
}
