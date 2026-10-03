import SwiftData
import Foundation

// App-side writer to the shared App Group UserDefaults.
// After every score change, call SharedStore.shared.publishWidgetEntry(...)
// so the widget's SharedWidgetStore.shared.latestEntry() gets fresh data.
final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore()
    private init() {}

    private let defaults = UserDefaults(suiteName: "group.com.yourapp.sportscore")
    private static let entryKey = "widget_score_entry"

    func publishWidgetEntry(sessionID: String, sportName: String, sportIcon: String, playerScores: [WidgetPlayerScore]) {
        let payload = WidgetEntryPayload(
            date: Date(),
            sessionID: sessionID,
            sportName: sportName,
            sportIcon: sportIcon,
            playerScores: playerScores
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults?.set(data, forKey: Self.entryKey)
    }

    // Reads pending widget +1 taps recorded by IncrementScoreIntent
    // and returns them so the live session can persist them to SwiftData.
    func drainPendingIncrements() -> [(sessionID: String, playerID: String)] {
        let key = "widget_pending_increments"
        guard let data = defaults?.data(forKey: key),
              let pending = try? JSONDecoder().decode([[String: String]].self, from: data)
        else { return [] }
        defaults?.removeObject(forKey: key)
        return pending.compactMap { dict in
            guard let s = dict["sessionID"], let p = dict["playerID"] else { return nil }
            return (sessionID: s, playerID: p)
        }
    }
}

// MARK: - Codable payload (mirrors WidgetDataModels in the extension)

struct WidgetEntryPayload: Codable {
    let date: Date
    let sessionID: String
    let sportName: String
    let sportIcon: String
    let playerScores: [WidgetPlayerScore]
}

struct WidgetPlayerScore: Codable {
    let playerID: String
    let playerName: String
    let scoreDisplay: String
}
