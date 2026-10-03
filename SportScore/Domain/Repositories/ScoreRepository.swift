import Foundation

protocol ScoreRepository: Sendable {
    func addEntry(_ entry: ScoreEntry, toFrameID: UUID) async throws
    func addFrame(_ frame: ScoreFrame, toSessionID: UUID) async throws
    func undoLastEntry(inSessionID: UUID, forPlayerID: UUID) async throws -> ScoreEntry?
    func fetchFrames(forSessionID: UUID) async throws -> [ScoreFrame]
}
