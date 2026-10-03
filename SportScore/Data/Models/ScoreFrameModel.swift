import SwiftData
import Foundation

@Model
final class ScoreFrameModel {
    @Attribute(.unique) var id: UUID
    var frameIndex: Int
    var playerID: UUID
    var subtotal: Int
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var entries: [ScoreEntryModel]
    @Relationship(deleteRule: .nullify) var session: GameSessionModel?

    init(id: UUID = UUID(), frameIndex: Int, playerID: UUID, timestamp: Date = .now) {
        self.id = id
        self.frameIndex = frameIndex
        self.playerID = playerID
        self.subtotal = 0
        self.timestamp = timestamp
        self.entries = []
    }

    func toDomain() -> ScoreFrame {
        // Keep the stored timestamp: engines replay points in recording order.
        var frame = ScoreFrame(id: id, playerID: playerID, frameIndex: frameIndex, timestamp: timestamp)
        frame.entries = entries.sorted { $0.timestamp < $1.timestamp }.map { $0.toDomain() }
        frame.subtotal = subtotal
        return frame
    }
}
