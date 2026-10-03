import Foundation

struct AddScoreEntryUseCase {
    let scoreRepo: any ScoreRepository

    /// Persists a frame built in memory so IDs and timestamps match the live session.
    func execute(frame: ScoreFrame, sessionID: UUID) async throws {
        try await scoreRepo.addFrame(frame, toSessionID: sessionID)
        for entry in frame.entries {
            try await scoreRepo.addEntry(entry, toFrameID: frame.id)
        }
    }
}
