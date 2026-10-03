import UserNotifications
import Foundation

enum NotificationScheduler {
    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(for task: UCTask) {
        guard let due = task.dueDate, due > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task due"
        content.body = task.title
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for task: UCTask) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
}
