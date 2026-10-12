import Foundation
import SwiftData
import Testing
@testable import FleetCheck

@Suite("Quick entries (typed or dictated)")
struct QuickEntryParserTests {
    let parser = QuickEntryParser()

    @Test func fuelWithLitersAndStation() {
        #expect(parser.parse("fuel 250 lei 34 L at OMV") == .expense(ExpenseDraft(category: .fuel, amount: 250, liters: 34, note: "Omv")))
    }

    @Test func romanianFuelYesterday() {
        guard case let .expense(draft) = parser.parse("am pus motorina 300 lei ieri, 40 litri") else { Issue.record("not parsed"); return }
        #expect(draft.category == .fuel)
        #expect(draft.amount == 300)
        #expect(draft.liters == 40)
        #expect(draft.daysAgo == 1)
    }

    @Test func otherCategories() {
        #expect(parser.parse("car wash 35")?.category == .carWash)
        #expect(parser.parse("parcare 10 lei")?.category == .parking)
        #expect(parser.parse("amenda 145")?.category == .fines)
    }

    @Test func earningsWithTipsBonusAndTrips() {
        #expect(parser.parse("uber 420 tips 30 bonus 50, 18 trips")
                == .earning(EarningDraft(platform: .uber, fares: 420, tips: 30, bonus: 50, trips: 18)))
        #expect(parser.parse("bolt 310 lei bacsis 12")
                == .earning(EarningDraft(platform: .bolt, fares: 310, tips: 12)))
    }

    @Test func nothingToSave() {
        #expect(parser.parse("fuel") == nil)
        #expect(parser.parse("hello there") == nil)
    }
}

private extension QuickEntry {
    var category: ExpenseCategory? {
        if case let .expense(draft) = self { return draft.category }
        return nil
    }
}

@Suite("Assistant questions without Apple Intelligence")
struct AssistantCommandParserTests {
    let parser = AssistantCommandParser()

    @Test(arguments: [
        ("How much did I make this week?", AssistantCommand.stats(.week, offset: 0)),
        ("how much did i earn last month", .stats(.month, offset: -1)),
        ("Cât am câștigat azi?", .stats(.day, offset: 0)),
        ("cat am facut saptamana trecuta", .stats(.week, offset: -1)),
        ("Compare this week with last week", .compare(.week)),
        ("How much did I spend on fuel this month?", .spending(.fuel, .month, offset: 0)),
        ("what did I spend this week", .spending(nil, .week, offset: 0)),
        ("When is my ITP due?", .reminders),
        ("Când expiră RCA?", .reminders),
        ("Which day pays best?", .bestDay),
        ("which shifts are missing earnings", .missingEarnings),
        ("tell me a joke", .unknown),
    ])
    func understandsQuestions(text: String, expected: AssistantCommand) {
        #expect(parser.parse(text) == expected)
    }

    @Test func statementsAreAdded() {
        #expect(parser.parse("fuel 250 lei") == .add(.expense(ExpenseDraft(category: .fuel, amount: 250))))
        #expect(parser.parse("uber 400") == .add(.earning(EarningDraft(platform: .uber, fares: 400))))
    }
}

@Suite("Receipts")
struct ReceiptTextParserTests {
    @Test func romanianFuelReceiptText() {
        let receipt = ReceiptTextParser().parse(lines: [
            "OMV PETROM MARKETING SRL", "Data: 11.10.2026  Ora 18:42", "MOTORINA MAXXMOTION",
            "34,12 L x 7,33  250,10", "SUBTOTAL  250,10", "TVA 21%  43,41", "TOTAL LEI  250,10",
        ])
        #expect(receipt.amount == 250.1)
        #expect(receipt.liters == 34.12)
        #expect(receipt.category == .fuel)
        #expect(receipt.vendor == "OMV")
        #expect(receipt.date.map { Calendar.current.component(.day, from: $0) } == 11)
    }

    @Test("Real OCR on a photographed-style fuel receipt")
    func scansReceiptImage() async throws {
        let url = try #require(Bundle(for: AssistantBundleToken.self).url(forResource: "receipt_fuel_ro", withExtension: "png"))
        let receipt = try await ReceiptScanner(useAppleIntelligence: false).scan(try Data(contentsOf: url))
        #expect(receipt.amount == 250.1)
        #expect(receipt.liters == 34.12)
        #expect(receipt.category == .fuel)
    }
}

@Suite("Insights and matching")
struct InsightTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    @Test func bestWeekdayNeedsEnoughData() {
        let composer = InsightComposer(calendar: calendar, money: MoneyFormatter(currencyCode: "RON"))
        // Oct 2026: the 5th is a Monday. Fridays earn 60/h, other days 40/h, two weeks of each.
        let days: [DayStats] = (5...18).map { day in
            let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
            let friday = calendar.component(.weekday, from: date) == 6
            return DayStats(day: date, earnings: friday ? 480 : 320, expenses: 0, km: 150, hours: 8)
        }
        let best = composer.bestWeekday(days)
        #expect(best?.name == "Friday")
        #expect(best?.perHour == 60)
        #expect(composer.bestWeekday(Array(days.prefix(3))) == nil)
    }

    @Test("A screenshot belongs to the shift it was taken during or right after")
    func shiftMatching() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let shifts = [(start: base, end: base.addingTimeInterval(8 * 3600)),
                      (start: base.addingTimeInterval(86_400), end: base.addingTimeInterval(86_400 + 6 * 3600))]
        let matcher = ShiftMatcher()
        #expect(matcher.index(for: base.addingTimeInterval(9 * 3600), in: shifts) == 0)
        #expect(matcher.index(for: base.addingTimeInterval(86_400 + 3600), in: shifts) == 1)
        #expect(matcher.index(for: base.addingTimeInterval(20 * 3600), in: shifts) == nil)
    }
}

@Suite("Instant answers from data")
@MainActor
struct DriverDataTests {
    @Test func addsAndAnswers() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let data = DriverData(context: container.mainContext)
        data.add(ExpenseDraft(category: .fuel, amount: 250, liters: 34))
        data.add(EarningDraft(platform: .uber, fares: 400, tips: 20))

        let stats = data.stats(.day)
        #expect(stats.earnings == 420)
        #expect(stats.expenses == 250)
        #expect(data.answer(.spending(.fuel, .day, offset: 0)).contains("250"))
        #expect(data.answer(.stats(.day, offset: 0)).hasPrefix("Today:"))
        #expect(data.answer(.reminders).contains("no reminders"))
    }
}

@Suite("Screenshot inbox")
@MainActor
struct ScreenshotInboxTests {
    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: try #require(Bundle(for: AssistantBundleToken.self).url(forResource: name, withExtension: "png")))
    }

    @Test("An earnings screenshot is offered, linked to its shift, and saved with one tap")
    func offersAndAccepts() async throws {
        let container = DataStore.makeContainer(inMemory: true)
        let data = DriverData(context: container.mainContext)
        let end = Date.now.addingTimeInterval(-3600)
        let shift = Shift(start: end.addingTimeInterval(-8 * 3600), end: end, distanceMeters: 180_000)
        container.mainContext.insert(shift)

        let inbox = ScreenshotInbox()
        let offered = await inbox.ingest(try fixture("bolt_day_gross_net"), id: "a", takenAt: end.addingTimeInterval(600),
                                         data: data, useAppleIntelligence: false)
        #expect(offered)
        let item = try #require(inbox.items.first)
        #expect(item.shift === shift)
        #expect(item.result.total == 318.4)

        inbox.accept(item, data: data)
        #expect(inbox.items.isEmpty)
        #expect(shift.earnings.count == 1)
        #expect(shift.earningsTotal == 318.4)
    }

    @Test("A receipt or random screenshot isn't offered as earnings")
    func ignoresOtherImages() async throws {
        let container = DataStore.makeContainer(inMemory: true)
        let inbox = ScreenshotInbox()
        let offered = await inbox.ingest(try fixture("receipt_fuel_ro"), id: "r", takenAt: .now,
                                         data: DriverData(context: container.mainContext), useAppleIntelligence: false)
        #expect(!offered)
        #expect(inbox.items.isEmpty)
    }
}

private final class AssistantBundleToken {}
