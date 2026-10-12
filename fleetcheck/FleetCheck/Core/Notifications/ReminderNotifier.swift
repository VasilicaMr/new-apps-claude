import Foundation
import UserNotifications

/// Schedules local notifications 30, 7 and 1 days before a dated reminder and on the day itself, at 9:00.
/// Everything is rebuilt from scratch on each change; with a handful of reminders this stays far below
/// iOS's 64 pending-notification limit.
@MainActor
enum ReminderNotifier {
    struct Item: Sendable {
        let id: UUID
        let title: String
        let dueDate: Date
    }

    private static let prefix = "reminder-"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ items: [Item], calendar: Calendar = .current, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        for item in items {
            for lead in ReminderPlanner.notificationLeadDays {
                guard let day = calendar.date(byAdding: .day, value: -lead, to: calendar.startOfDay(for: item.dueDate)),
                      let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                      fireDate > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = switch lead {
                case 0: "Due today."
                case 1: "Due tomorrow."
                default: "Due in \(lead) days, on \(item.dueDate.formatted(date: .abbreviated, time: .omitted))."
                }
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(item.id)-\(lead)", content: content, trigger: trigger))
            }
        }
    }
}
