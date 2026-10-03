import Foundation
import WidgetKit

// Widget-side read/write via App Group UserDefaults.
// The main app writes ScoreWidgetEntry JSON here after every score change;
// the widget reads it for its timeline and the +1 intent optimistically bumps it.
final class SharedWidgetStore: @unchecked Sendable {
    static let shared = SharedWidgetStore()
    private init() {}

    private let defaults = UserDefaults(suiteName: "group.com.yourapp.sportscore")
    private static let entryKey = "widget_score_entry"
    private static let pendingKey = "widget_pending_increments"

    func latestEntry() -> ScoreWidgetEntry? {
        guard let data = defaults?.data(forKey: Self.entryKey),
              let entry = try? JSONDecoder().decode(ScoreWidgetEntry.self, from: data)
        else { return nil }
        return entry
    }

    // Called by IncrementScoreIntent — optimistic bump + records pending delta for the app to persist
    func incrementScore(sessionID: String, playerID: String) {
        var pending = pendingIncrements()
        pending.append(["sessionID": sessionID, "playerID": playerID])
        if let data = try? JSONEncoder().encode(pending) {
            defaults?.set(data, forKey: Self.pendingKey)
        }

        guard var entry = latestEntry() else { return }
        let updated = entry.playerScores.map { ps -> PlayerWidgetScore in
            guard ps.playerID == playerID else { return ps }
            let current = Int(ps.scoreDisplay) ?? 0
            return PlayerWidgetScore(
                playerID: ps.playerID,
                playerName: ps.playerName,
                scoreDisplay: "\(current + 1)"
            )
        }
        saveEntry(ScoreWidgetEntry(
            date: .now,
            sessionID: entry.sessionID,
            sportName: entry.sportName,
            sportIcon: entry.sportIcon,
            playerScores: updated
        ))
    }

    func pendingIncrements() -> [[String: String]] {
        guard let data = defaults?.data(forKey: Self.pendingKey),
              let pending = try? JSONDecoder().decode([[String: String]].self, from: data)
        else { return [] }
        return pending
    }

    func clearPendingIncrements() {
        defaults?.removeObject(forKey: Self.pendingKey)
    }

    private func saveEntry(_ entry: ScoreWidgetEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults?.set(data, forKey: Self.entryKey)
    }
}
