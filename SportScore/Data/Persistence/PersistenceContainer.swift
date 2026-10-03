import SwiftData
import Foundation

enum PersistenceContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            PlayerModel.self,
            GameSessionModel.self,
            ScoreFrameModel.self,
            ScoreEntryModel.self
        ])
        #if DEBUG
        let config = ModelConfiguration(
            "SportScore",
            schema: schema,
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
