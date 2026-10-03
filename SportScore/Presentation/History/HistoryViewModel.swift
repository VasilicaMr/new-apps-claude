import Foundation

@Observable
@MainActor
final class HistoryViewModel {
    var sessions: [GameSession] = []
    var lockedCount: Int = 0
    var isLoading: Bool = false

    private let fetchSessions: FetchSessionsUseCase
    private let deleteSession: DeleteSessionUseCase

    init(fetchSessions: FetchSessionsUseCase, deleteSession: DeleteSessionUseCase? = nil) {
        self.fetchSessions = fetchSessions
        self.deleteSession = deleteSession ?? DeleteSessionUseCase(sessionRepo: EmptySessionRepository())
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let all = (try? await fetchSessions.execute()) ?? []
        if PremiumManager.shared.isPremium {
            sessions = all
            lockedCount = 0
        } else {
            sessions = Array(all.prefix(PremiumManager.freeHistoryLimit))
            lockedCount = max(0, all.count - PremiumManager.freeHistoryLimit)
        }
    }

    func deleteSessions(at offsets: IndexSet) async {
        for index in offsets {
            let session = sessions[index]
            try? await deleteSession.execute(id: session.id)
        }
        sessions.remove(atOffsets: offsets)
    }
}

// Null object to allow optional init
private struct EmptySessionRepository: SessionRepository {
    func fetchAll() async throws -> [GameSession] { [] }
    func fetchActive() async throws -> [GameSession] { [] }
    func fetch(id: UUID) async throws -> GameSession? { nil }
    func save(_ session: GameSession) async throws {}
    func delete(id: UUID) async throws {}
}
