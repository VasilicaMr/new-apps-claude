import Foundation
import Testing
@testable import FleetCheck

@Suite("Free screenshot reads")
struct ScreenshotAllowanceTests {
    let calendar = Calendar(identifier: .gregorian)
    func date(_ month: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: month, day: day))! }

    func allowance() -> ScreenshotAllowance {
        let suite = "ScreenshotAllowanceTests.\(UUID())"
        return ScreenshotAllowance(defaults: UserDefaults(suiteName: suite)!, calendar: calendar)
    }

    @Test func freeDriversRunOutAfterTheMonthlyLimit() {
        let allowance = allowance()
        let now = date(10, 26)
        #expect(allowance.remaining(isPro: false, now: now) == ScreenshotAllowance.freeReadsPerMonth)
        for _ in 0..<ScreenshotAllowance.freeReadsPerMonth { allowance.recordRead(now: now) }
        #expect(allowance.remaining(isPro: false, now: now) == 0)
        #expect(!allowance.canRead(isPro: false, now: now))
    }

    @Test("A new month starts a new allowance")
    func resetsEachMonth() {
        let allowance = allowance()
        for _ in 0..<ScreenshotAllowance.freeReadsPerMonth { allowance.recordRead(now: date(10, 31)) }
        #expect(allowance.canRead(isPro: false, now: date(11, 1)))
        #expect(allowance.remaining(isPro: false, now: date(11, 1)) == ScreenshotAllowance.freeReadsPerMonth)
    }

    @Test func proHasNoLimit() {
        let allowance = allowance()
        for _ in 0..<50 { allowance.recordRead(now: date(10, 26)) }
        #expect(allowance.remaining(isPro: true, now: date(10, 26)) == nil)
        #expect(allowance.canRead(isPro: true, now: date(10, 26)))
    }
}
