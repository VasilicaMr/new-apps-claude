import Foundation

/// When an open house runs. The date and time are always formatted here, never by the
/// language model, so the video and caption show exactly what the agent picked.
struct OpenHouseSchedule: Codable, Equatable {
    var start: Date
    var end: Date

    var isValid: Bool { end > start }

    /// The title-card badge, e.g. "Open House Sat 2 – 4 PM" (minutes only when needed).
    func badge(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let when = formatted(template: showsMinutes(timeZone: timeZone) ? "EEEjmm" : "EEEj",
                             locale: locale, timeZone: timeZone)
        return String(localized: "Open House \(when)",
                      comment: "Headline badge on an open house video's title card, e.g. 'Open House Sat 2 – 4 PM'")
    }

    /// The full date and time for narration and captions, e.g. "Saturday, October 4, 2 – 4 PM".
    func spokenWhen(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        formatted(template: showsMinutes(timeZone: timeZone) ? "EEEEMMMMdjmm" : "EEEEMMMMdj",
                  locale: locale, timeZone: timeZone)
    }

    /// The next Saturday, 1–3 PM: the most common open house slot, as a starting point.
    static func suggested(after now: Date = .now, calendar: Calendar = .current) -> OpenHouseSchedule {
        let start = calendar.nextDate(after: now,
                                      matching: DateComponents(hour: 13, minute: 0, weekday: 7),
                                      matchingPolicy: .nextTime) ?? now
        return OpenHouseSchedule(start: start, end: start.addingTimeInterval(2 * 60 * 60))
    }

    private func showsMinutes(timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.minute, from: start) != 0 || calendar.component(.minute, from: end) != 0
    }

    private func formatted(template: String, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateTemplate = template
        return formatter.string(from: start, to: end)
    }
}
