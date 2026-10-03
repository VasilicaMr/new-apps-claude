import Foundation
import UserNotifications

/// Posts a single local notification summarizing a finished batch export.
/// Requests `.alert`/`.sound` authorization lazily, on first use — if denied,
/// the queue still finishes normally (see `BatchExportQueueUseCase`), it just
/// posts nothing. Never blocks the queue on the permission prompt's outcome.
final class UserNotificationExportNotifier: ExportNotifying {
    private let center = UNUserNotificationCenter.current()

    func notifyBatchFinished(succeeded: Int, failed: Int) async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Inbox export finished")
        content.body = body(succeeded: succeeded, failed: failed)
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    private func body(succeeded: Int, failed: Int) -> String {
        guard failed == 0 else {
            return String(localized: "\(succeeded) exported, \(failed) failed. Open Realto to check what went wrong.")
        }
        return succeeded == 1
            ? String(localized: "1 video exported.")
            : String(localized: "\(succeeded) videos exported.")
    }
}
