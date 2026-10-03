import SwiftData
import Foundation

@Model
final class Thought {
    var id: UUID = UUID()
    var content: String = ""
    var createdAt: Date = Date()

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
    }
}
