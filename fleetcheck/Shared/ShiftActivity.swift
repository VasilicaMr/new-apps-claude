import ActivityKit
import AppIntents
import Foundation

// Compiled into both the app and the widget extension.

/// Lock Screen / Dynamic Island card while a shift is running.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Set when the shift has ended; the card then shows a short summary instead of the End button.
        var endDate: Date?
    }

    var startDate: Date
}

/// "End shift" from the Live Activity button or Siri. The widget only declares it;
/// `perform()` always runs in the app process, where `ShiftControl` is wired to `ShiftStore`.
struct EndShiftIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Shift"
    static let description = IntentDescription("Ends the current shift.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let endShift = ShiftControl.endShift else { return .result(dialog: "DriveCap isn't ready yet.") }
        // Awaited: the app is in the background here and is suspended as soon as this returns,
        // so anything left in a detached task (like ending the Live Activity) might never run.
        let summary = await endShift()
        return .result(dialog: summary.map { IntentDialog(stringLiteral: $0) } ?? "No shift is running.")
    }
}

@MainActor
enum ShiftControl {
    /// Ends the running shift and returns a short spoken summary, or nil if none was running.
    static var endShift: (@MainActor () async -> String?)?
}
