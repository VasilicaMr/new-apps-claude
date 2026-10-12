import SwiftData
import Foundation

enum PersistenceContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            PlayerModel.self,
            GameSessionModel.self,
            ScoreFrameModel.self,
            ScoreEntryModel.self,
            CustomGameModel.self
        ])
        // The store keeps its pre-rename name: changing it would start users on an empty store.
        #if DEBUG
        // UI tests start from an empty, throwaway store.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let config = ModelConfiguration(
            "SportScore",
            schema: schema,
            isStoredInMemoryOnly: isUITesting,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        #else
        let config = ModelConfiguration(
            "SportScore",
            schema: schema,
            groupContainer: .identifier("group.com.yourapp.sportscore"),
            cloudKitDatabase: .automatic
        )
        #endif
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
