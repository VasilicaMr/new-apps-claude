import Foundation

struct SnookerConfig: Codable, Sendable {
    var framesInMatch: Int = 9
    var colourSafeMode: Bool = false
}

/// Entries:
/// - pot: value 1…7, metadata["ball"]
/// - miss / end of break: value 0
/// - foul: value 0, metadata["foul"] = penalty (4…7), credited to the opponent
/// - frame won: value 0, label "frameWin"
final class SnookerScoringEngine: ScoringEngine {
    let sport: SportType = .snooker

    private struct State {
        var framePoints: [UUID: Int] = [:]
        var framesWon: [UUID: Int] = [:]
        var currentBreak: [UUID: Int] = [:]
        var highBreak: [UUID: Int] = [:]
    }

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: SnookerConfig.self) ?? SnookerConfig()
        let framesNeeded = config.framesInMatch / 2 + 1
        let state = buildState(session, adding: (playerID, entry))
        let won = state.framesWon[playerID] ?? 0
        let isMatchWin = entry.label == "frameWin" && won >= framesNeeded
        let isPot = entry.value > 0 && entry.label != "frameWin"

        return ScoringResult(
            displayScore: display(state, playerID: playerID, framesInMatch: config.framesInMatch),
            isGameOver: isMatchWin,
            winner: isMatchWin ? playerID : nil,
            turnAdvances: !isPot && entry.label != "frameWin"
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: SnookerConfig.self) ?? SnookerConfig()
        let state = buildState(session, adding: nil)
        return state.framesWon.values.contains { $0 >= config.framesInMatch / 2 + 1 }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let config = session.config(as: SnookerConfig.self) ?? SnookerConfig()
        return display(buildState(session, adding: nil), playerID: playerID, framesInMatch: config.framesInMatch)
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let state = buildState(session, adding: nil)
        let brk = state.currentBreak[playerID] ?? 0
        return EntryContext(prompt: brk > 0 ? "Break: \(brk)" : "Tap each ball potted · Miss ends the visit")
    }

    private func display(_ state: State, playerID: UUID, framesInMatch: Int) -> DisplayScore {
        DisplayScore(
            primary: "\(state.framePoints[playerID] ?? 0)",
            secondary: "Frames \(state.framesWon[playerID] ?? 0) (best of \(framesInMatch))",
            detail: "High break \(state.highBreak[playerID] ?? 0)"
        )
    }

    private func buildState(_ session: GameSession, adding extra: (UUID, ScoreEntry)?) -> State {
        var s = State()
        for p in session.players {
            s.framePoints[p.id] = 0
            s.framesWon[p.id] = 0
            s.currentBreak[p.id] = 0
            s.highBreak[p.id] = 0
        }
        var events = session.chronologicalEntries.map { ($0.playerID, $0.entry) }
        if let extra { events.append(extra) }

        for (pid, e) in events {
            // Any shot by one player ends everyone else's break.
            for other in session.players where other.id != pid { s.currentBreak[other.id] = 0 }

            if e.label == "frameWin" {
                s.framesWon[pid, default: 0] += 1
                for p in session.players {
                    s.framePoints[p.id] = 0
                    s.currentBreak[p.id] = 0
                }
            } else if let foul = e.metadata?["foul"].flatMap(Int.init), foul > 0 {
                s.currentBreak[pid] = 0
                for p in session.players where p.id != pid {
                    s.framePoints[p.id, default: 0] += foul
                }
            } else if e.value > 0 {
                s.framePoints[pid, default: 0] += e.value
                s.currentBreak[pid, default: 0] += e.value
                s.highBreak[pid] = max(s.highBreak[pid] ?? 0, s.currentBreak[pid] ?? 0)
            } else {
                s.currentBreak[pid] = 0
            }
        }
        return s
    }
}
