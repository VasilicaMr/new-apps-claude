import Foundation

/// Big on-screen confirmation of the last recorded entry, with a one-tap undo.
struct ScoreFlash: Equatable, Identifiable {
    let id = UUID()
    let playerID: UUID
    let playerName: String
    let text: String
    var detail: String? = nil
    let isBust: Bool
}

@Observable
@MainActor
final class LiveScoreViewModel {
    var session: GameSession?
    var currentScores: [UUID: DisplayScore] = [:]
    var entryContexts: [UUID: EntryContext] = [:]
    var isGameOver: Bool = false
    var winner: Player?
    var isLoading: Bool = false
    var errorMessage: String?
    /// Short, non-blocking feedback such as "Bust" or "Only 3 pins standing".
    var notice: String?
    var flash: ScoreFlash?

    /// Writes run one after another so an undo never overtakes a pending save.
    private var pendingWrite: Task<Void, Never>?

    private let sessionID: UUID
    private let fetchSessions: FetchSessionsUseCase
    private let addEntry: AddScoreEntryUseCase
    private let computeScore: ComputeScoreUseCase
    private let undo: UndoLastEntryUseCase
    private let endSession: EndSessionUseCase

    init(
        sessionID: UUID,
        fetchSessions: FetchSessionsUseCase,
        addEntry: AddScoreEntryUseCase,
        computeScore: ComputeScoreUseCase,
        undo: UndoLastEntryUseCase,
        endSession: EndSessionUseCase
    ) {
        self.sessionID = sessionID
        self.fetchSessions = fetchSessions
        self.addEntry = addEntry
        self.computeScore = computeScore
        self.undo = undo
        self.endSession = endSession
    }

    private var engine: (any ScoringEngine)? {
        session.map { ScoringEngineFactory().engine(for: $0.sport, variant: $0.variant) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let sessions = try await fetchSessions.execute()
            session = sessions.first { $0.id == sessionID }
            refreshScores()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Records an entry and returns whether the turn should pass to the next player.
    @discardableResult
    func submitEntry(_ entry: ScoreEntry, for player: Player) -> Bool {
        guard var currentSession = session, !isGameOver else { return false }

        let result = computeScore.execute(session: currentSession, newEntry: entry, for: player.id)

        if let rejection = result.rejection {
            Haptics.error()
            notice = rejection
            return false
        }

        // A bust is still recorded (as a zero marker) so the engine knows the turn ended.
        let recorded = result.isBust
            ? ScoreEntry(value: 0, label: "bust", metadata: ["bust": "true"])
            : entry

        let frameIndex = (currentSession.frames(for: player.id).map(\.frameIndex).max() ?? -1) + 1
        var frame = ScoreFrame(playerID: player.id, frameIndex: frameIndex, timestamp: recorded.timestamp)
        frame.entries = [recorded]
        frame.subtotal = recorded.value

        // Update memory first so rapid taps always see the latest state.
        currentSession.frames.append(frame)
        session = currentSession
        refreshScores()

        if result.isBust {
            Haptics.error()
        } else {
            // Heavy so it can be felt in a noisy room.
            Haptics.impact(.heavy)
        }
        flash = ScoreFlash(
            playerID: player.id,
            playerName: player.name,
            text: result.isBust ? "Bust" : Self.describe(entry),
            detail: result.isBust ? result.notes : nil,
            isBust: result.isBust
        )

        let sessionID = currentSession.id
        enqueueWrite { [weak self] in
            guard let self else { return }
            do {
                try await addEntry.execute(frame: frame, sessionID: sessionID)
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
        }

        if result.isGameOver {
            isGameOver = true
            winner = result.winner.flatMap { wID in currentSession.players.first { $0.id == wID } }
            session?.isActive = false
            session?.winnerID = result.winner
            Haptics.success()
            let winnerID = result.winner
            enqueueWrite { [endSession] in
                try? await endSession.execute(sessionID: sessionID, winnerID: winnerID)
            }
        }
        return result.turnAdvances
    }

    func undoLast(for player: Player) async {
        flash = nil
        await pendingWrite?.value
        guard let sess = session else { return }
        do {
            _ = try await undo.execute(sessionID: sess.id, playerID: player.id)
            if !sess.isActive { try await endSession.reopen(sessionID: sess.id) }
            await load()
            Haptics.selection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Undoes the most recent entry in the game, whoever it belonged to.
    /// Returns that player so the UI can hand the turn back to them.
    @discardableResult
    func undoMostRecent() async -> Player? {
        guard let sess = session,
              let last = sess.frames.max(by: { $0.timestamp < $1.timestamp }),
              let player = sess.players.first(where: { $0.id == last.playerID }) else { return nil }
        await undoLast(for: player)
        return player
    }

    func endGameEarly(winnerID: UUID?) async {
        await pendingWrite?.value
        try? await endSession.execute(sessionID: sessionID, winnerID: winnerID)
        session?.isActive = false
        session?.winnerID = winnerID
        winner = winnerID.flatMap { id in session?.players.first { $0.id == id } }
        isGameOver = true
    }

    /// Next player in seating order who still has something to enter.
    func nextPlayer(after playerID: UUID) -> UUID? {
        guard let players = session?.players,
              let idx = players.firstIndex(where: { $0.id == playerID }) else { return nil }
        for step in 1...players.count {
            let candidate = players[(idx + step) % players.count]
            if entryContexts[candidate.id]?.isPlayerFinished != true { return candidate.id }
        }
        return playerID
    }

    /// Short human description of an entry, e.g. "+3", "T20", "Frame won".
    static func describe(_ entry: ScoreEntry) -> String {
        switch entry.label {
        case "frameWin":   return "Frame won"
        case "gameWin":    return "Game won"
        case "rackWin":    return "Rack won"
        case "win":        return "Win"
        case "draw":       return "Draw"
        case "loss":       return "Loss"
        case "pegOut":     return "Pegged out"
        case "king":       return "King toppled"
        case "hoop":       return "Hoop"
        case "eliminated": return "Busted out"
        case "territory":  return "Territory \(entry.value)"
        case "capture":    return "+\(entry.value) captured"
        case "kubb":       return "\(entry.value) kubb\(entry.value == 1 ? "" : "s")"
        default: break
        }
        if let foul = entry.metadata?["foul"] { return "Foul (\(foul))" }
        if entry.metadata?["miss"] == "true" { return "Miss" }
        if let segment = entry.metadata?["segment"], let mult = entry.metadata?["multiplier"] {
            if segment == "0" { return "Miss" }
            if segment == "bull" { return mult == "2" ? "Bull 50" : "Bull 25" }
            let prefix = mult == "3" ? "T" : mult == "2" ? "D" : ""
            return "\(prefix)\(segment)"
        }
        if let cube = entry.metadata?["cubeValue"], cube != "1" { return "+\(entry.value) ×\(cube)" }
        return entry.value < 0
            ? QuickScorePresets.format(entry.value)
            : QuickScorePresets.format(entry.value, signed: true)
    }

    private func enqueueWrite(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pendingWrite
        pendingWrite = Task {
            await previous?.value
            await operation()
        }
    }

    private func refreshScores() {
        guard let sess = session, let engine else { return }
        for player in sess.players {
            currentScores[player.id] = engine.currentScore(for: player.id, in: sess)
            entryContexts[player.id] = engine.entryContext(for: player.id, in: sess)
        }
        isGameOver = !sess.isActive
        winner = sess.winnerID.flatMap { wID in sess.players.first { $0.id == wID } }
    }
}
