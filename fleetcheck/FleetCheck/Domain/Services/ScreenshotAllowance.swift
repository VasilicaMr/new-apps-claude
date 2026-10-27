import Foundation

/// Free drivers get a few earnings screenshots read each calendar month; Pro reads without a limit.
/// Only screenshots that gave earnings count, so a failed read never costs the driver one.
struct ScreenshotAllowance {
    static let freeReadsPerMonth = 10

    var defaults: UserDefaults = .standard
    var calendar: Calendar = .current

    func used(now: Date = .now) -> Int { defaults.integer(forKey: key(now)) }

    /// Nil means unlimited.
    func remaining(isPro: Bool, now: Date = .now) -> Int? {
        isPro ? nil : max(0, Self.freeReadsPerMonth - used(now: now))
    }

    func canRead(isPro: Bool, now: Date = .now) -> Bool { remaining(isPro: isPro, now: now).map { $0 > 0 } ?? true }

    func recordRead(now: Date = .now) {
        defaults.set(used(now: now) + 1, forKey: key(now))
    }

    private func key(_ date: Date) -> String {
        let month = calendar.dateComponents([.year, .month], from: date)
        return "screenshotReads.\(month.year ?? 0)-\(month.month ?? 0)"
    }
}
