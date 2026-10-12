import ActivityKit
import AppIntents
import Foundation

// Compiled into both the app and the widget extension.

/// Lock Screen / Dynamic Island card while a shift is running.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceKm: Double
        var isWaitingForGPS: Bool
    }

    var startDate: Date
}

/// "End shift" from the Live Activity button or Siri. The widget only declares it;
/// `perform()` always runs in the app process, where `ShiftControl` is wired to `ShiftStore`.
struct EndShiftIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Shift"
    static let description = IntentDescription("Stops tracking the current shift.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let endShift = ShiftControl.endShift else { return .result(dialog: "FleetCheck isn't ready yet.") }
        let summary = await endShift()
        return .result(dialog: IntentDialog(stringLiteral: summary ?? "No shift is running."))
    }
}

@MainActor
enum ShiftControl {
    /// Ends the running shift and returns a short spoken summary, or nil if none was running.
    static var endShift: (@MainActor () async -> String?)?
}
