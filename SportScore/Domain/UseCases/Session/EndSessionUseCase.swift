import Foundation

struct EndSessionUseCase {
    let sessionRepo: any SessionRepository

    func execute(sessionID: UUID, winnerID: UUID?) async throws {
        guard var session = try await sessionRepo.fetch(id: sessionID) else { return }
        session.isActive = false
        session.endedAt = .now
        session.winnerID = winnerID
        try await sessionRepo.save(session)
    }

    /// Re-opens a finished session, e.g. after undoing the entry that ended it.
    func reopen(sessionID: UUID) async throws {
        guard var session = try await sessionRepo.fetch(id: sessionID) else { return }
        session.isActive = true
        session.endedAt = nil
        session.winnerID = nil
        try await sessionRepo.save(session)
    }
}
