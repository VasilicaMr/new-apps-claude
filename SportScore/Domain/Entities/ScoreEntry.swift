import Foundation

struct ScoreEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let value: Int
    var label: String?
    var metadata: [String: String]?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        value: Int,
        label: String? = nil,
        metadata: [String: String]? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.value = value
        self.label = label
        self.metadata = metadata
        self.timestamp = timestamp
    }
}
