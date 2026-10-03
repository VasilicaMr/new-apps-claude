import SwiftData
import Foundation

@Model
final class PlayerModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarData: Data?
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \GameSessionModel.players) var sessions: [GameSessionModel]

    init(id: UUID = UUID(), name: String, avatarData: Data? = nil) {
        self.id = id
        self.name = name
        self.avatarData = avatarData
        self.createdAt = .now
        self.sessions = []
    }

    func toDomain() -> Player {
        Player(id: id, name: name, avatarData: avatarData)
    }
}
