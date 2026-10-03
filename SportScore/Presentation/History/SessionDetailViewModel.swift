import Foundation

@Observable
@MainActor
final class SessionDetailViewModel {
    var session: GameSession?
    var isLoading: Bool = false
    var winner: Player?

    private let sessionID: UUID
    private let fetchSessions: FetchSessionsUseCase

    init(sessionID: UUID, fetchSessions: FetchSessionsUseCase) {
        self.sessionID = sessionID
        self.fetchSessions = fetchSessions
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let sessions = try? await fetchSessions.execute() {
            session = sessions.first { $0.id == sessionID }
            winner = session.flatMap { s in
                s.winnerID.flatMap { wID in s.players.first { $0.id == wID } }
            }
        }
    }

    func finalScore(for player: Player, in session: GameSession) -> String {
        let engine = ScoringEngineFactory().engine(for: session.sport, variant: session.variant)
        return engine.currentScore(for: player.id, in: session).primary
    }
}
