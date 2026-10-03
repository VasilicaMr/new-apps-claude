import AppIntents
import WidgetKit

struct IncrementScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Point"
    static let description = IntentDescription("Adds one point to a player in the active session.")

    @Parameter(title: "Session ID") var sessionID: String
    @Parameter(title: "Player ID") var playerID: String

    init() {}

    init(sessionID: String, playerID: String) {
        self.sessionID = sessionID
        self.playerID = playerID
    }

    func perform() async throws -> some IntentResult {
        SharedWidgetStore.shared.incrementScore(sessionID: sessionID, playerID: playerID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
