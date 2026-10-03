import Foundation

struct ScoreFrame: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let playerID: UUID
    let frameIndex: Int
    var entries: [ScoreEntry]
    var subtotal: Int
    var timestamp: Date

    init(id: UUID = UUID(), playerID: UUID, frameIndex: Int, timestamp: Date = .now) {
        self.id = id
        self.playerID = playerID
        self.frameIndex = frameIndex
        self.entries = []
        self.subtotal = 0
        self.timestamp = timestamp
    }

    var totalValue: Int {
        entries.reduce(0) { $0 + $1.value }
    }
}
