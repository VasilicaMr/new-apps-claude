import SwiftData
import Foundation

@Model
final class GameSessionModel {
    @Attribute(.unique) var id: UUID
    var sportRawValue: String
    var variant: String?
    var startedAt: Date
    var endedAt: Date?
    var isActive: Bool
    var metadataJSON: Data?
    var winnerID: UUID?
    @Relationship(deleteRule: .cascade) var frames: [ScoreFrameModel]
    var players: [PlayerModel]
    /// SwiftData does not preserve to-many order, so the seating order is stored separately.
    var playerOrder: [UUID] = []

    init(id: UUID = UUID(), sport: SportType, variant: String? = nil) {
        self.id = id
        self.sportRawValue = sport.rawValue
        self.variant = variant
        self.startedAt = .now
        self.isActive = true
        self.frames = []
        self.players = []
    }

    var sport: SportType? { SportType(rawValue: sportRawValue) }

    private var orderedPlayers: [PlayerModel] {
        guard !playerOrder.isEmpty else { return players }
        return players.sorted {
            (playerOrder.firstIndex(of: $0.id) ?? .max) < (playerOrder.firstIndex(of: $1.id) ?? .max)
        }
    }

    func toDomain() -> GameSession {
        var session = GameSession(
            id: id,
            sport: sport ?? .darts,
            variant: variant,
            players: orderedPlayers.map { $0.toDomain() },
            configJSON: metadataJSON
        )
        session.isActive = isActive
        session.endedAt = endedAt
        session.winnerID = winnerID
        session.frames = frames.sorted { $0.frameIndex < $1.frameIndex }.map { $0.toDomain() }
        return session
    }
}
