import SwiftData
import Foundation

@Model
final class ScoreEntryModel {
    @Attribute(.unique) var id: UUID
    var value: Int
    var label: String?
    var metadataJSON: Data?
    var timestamp: Date
    @Relationship(deleteRule: .nullify) var frame: ScoreFrameModel?

    init(id: UUID = UUID(), value: Int, label: String? = nil, metadata: [String: String]? = nil, timestamp: Date = .now) {
        self.id = id
        self.value = value
        self.label = label
        self.metadataJSON = metadata.flatMap { try? JSONEncoder().encode($0) }
        self.timestamp = timestamp
    }

    func toDomain() -> ScoreEntry {
        let metadata = metadataJSON.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
        return ScoreEntry(id: id, value: value, label: label, metadata: metadata, timestamp: timestamp)
    }
}
