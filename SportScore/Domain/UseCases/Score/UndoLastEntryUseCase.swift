import Foundation

struct UndoLastEntryUseCase {
    let scoreRepo: any ScoreRepository

    func execute(sessionID: UUID, playerID: UUID) async throws -> ScoreEntry? {
        try await scoreRepo.undoLastEntry(inSessionID: sessionID, forPlayerID: playerID)
    }
}
