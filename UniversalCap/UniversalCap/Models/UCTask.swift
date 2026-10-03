import SwiftData
import Foundation

@Model
final class UCTask {
    var id: UUID = UUID()
    var title: String = ""
    var dueDate: Date? = nil
    var isCompleted: Bool = false
    var createdAt: Date = Date()

    init(title: String, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = false
        self.createdAt = Date()
    }
}
