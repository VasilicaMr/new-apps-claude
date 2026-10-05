import Foundation

/// A simple HabitKit-style goal, e.g. "Family Game Night — once a week".
/// Stored only on this Apple TV.
struct GamePlan: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = ""
    var symbol: String = "flame.fill"
    /// Only games with this title count (e.g. "Uno"); `nil` means any game.
    var gameTitle: String?
    var timesPerWeek: Int = 1
    /// Days ticked by hand (start of day), for games played away from the TV.
    var manualDays: Set<Date> = []
}

struct PlanProgress {
    var doneDays: Set<Date> = []
    var thisWeek = 0
    /// Weeks in a row the goal was met (the current week counts once it's met).
    var streak = 0
    var isDoneToday = false
}

extension GamePlan {
    func progress(sessions: [GameSession], calendar: Calendar = .current, now: Date = .now) -> PlanProgress {
        var days = manualDays
        for session in sessions where gameTitle == nil || session.title == gameTitle {
            days.insert(calendar.startOfDay(for: session.startedAt))
        }

        func count(inWeekOf date: Date) -> Int {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
            return days.filter { week.contains($0) }.count
        }

        var progress = PlanProgress(doneDays: days)
        progress.thisWeek = count(inWeekOf: now)
        progress.isDoneToday = days.contains(calendar.startOfDay(for: now))

        // The current week only adds to the streak once its goal is met; it never breaks it.
        var week = now
        if progress.thisWeek >= timesPerWeek { progress.streak = 1 }
        for _ in 0..<104 {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
            guard count(inWeekOf: week) >= timesPerWeek else { break }
            progress.streak += 1
        }
        return progress
    }
}

/// Plans live in UserDefaults: the one store tvOS never purges, and plenty for a few plans.
@Observable
@MainActor
final class GamePlansStore {
    private(set) var plans: [GamePlan] = []

    private let defaults: UserDefaults
    private static let key = "tv.gamePlans.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([GamePlan].self, from: data) {
            plans = saved
        }
    }

    func contains(_ plan: GamePlan) -> Bool {
        plans.contains { $0.id == plan.id }
    }

    func save(_ plan: GamePlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        persist()
    }

    func delete(_ plan: GamePlan) {
        plans.removeAll { $0.id == plan.id }
        persist()
    }

    func toggleToday(_ plan: GamePlan, calendar: Calendar = .current) {
        guard var updated = plans.first(where: { $0.id == plan.id }) else { return }
        let today = calendar.startOfDay(for: .now)
        if updated.manualDays.contains(today) {
            updated.manualDays.remove(today)
        } else {
            updated.manualDays.insert(today)
        }
        save(updated)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(plans) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
