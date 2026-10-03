import Foundation

struct Player: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var avatarData: Data?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, avatarData: Data? = nil) {
        self.id = id
        self.name = name
        self.avatarData = avatarData
        self.createdAt = .now
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
