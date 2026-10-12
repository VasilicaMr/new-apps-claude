import Foundation

enum Urgency: Int, Comparable, Sendable {
    case ok, soon, overdue

    static func < (lhs: Urgency, rhs: Urgency) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A reminder's due point, by date, by odometer, or both (whichever comes first).
struct DueRule: Sendable, Hashable {
    var dueDate: Date?
    var dueKm: Double?
    var repeatMonths: Int?
    var repeatKm: Double?
}

struct ReminderStatus: Sendable, Hashable {
    let urgency: Urgency
    let daysLeft: Int?
    let kmLeft: Double?
}

/// Decides what is due and what the next due point is after the driver marks it done.
struct ReminderPlanner: Sendable {
    var calendar: Calendar = .current
    var soonDays = 30
    var soonKm: Double = 1_000

    func status(of rule: DueRule, today: Date, odometerKm: Double) -> ReminderStatus {
        let daysLeft = rule.dueDate.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: $0)).day ?? 0
        }
        let kmLeft = rule.dueKm.map { $0 - odometerKm }

        let urgency: Urgency
        if (daysLeft.map { $0 < 0 } ?? false) || (kmLeft.map { $0 <= 0 } ?? false) {
            urgency = .overdue
        } else if (daysLeft.map { $0 <= soonDays } ?? false) || (kmLeft.map { $0 <= soonKm } ?? false) {
            urgency = .soon
        } else {
            urgency = .ok
        }
        return ReminderStatus(urgency: urgency, daysLeft: daysLeft, kmLeft: kmLeft)
    }

    /// Next due point after completing the task on `doneDate` at `odometerKm`.
    /// Date-based items renew from the old due date when done early (insurance periods don't shift),
    /// and from the completion date when done late.
    func nextRule(after rule: DueRule, doneDate: Date, odometerKm: Double) -> DueRule {
        var next = rule
        if let months = rule.repeatMonths, months > 0 {
            let doneDay = calendar.startOfDay(for: doneDate)
            let renewFrom = rule.dueDate.map { max($0, doneDay) } ?? doneDay
            next.dueDate = calendar.date(byAdding: .month, value: months, to: renewFrom)
        }
        if let km = rule.repeatKm, km > 0 {
            next.dueKm = odometerKm + km
        }
        return next
    }

    /// Days before a due date when a notification fires.
    static let notificationLeadDays = [30, 7, 1, 0]
}
