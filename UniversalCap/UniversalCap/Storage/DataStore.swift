import SwiftData
import Foundation

// Each App Intent creates its own ModelContext to avoid actor-isolation issues.
// CloudKit config is shared with the main app so intents write to the same synced store.
enum DataStore {
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
        return try ModelContainer(for: Thought.self, Expense.self, UCTask.self,
                                  configurations: config)
    }
}
