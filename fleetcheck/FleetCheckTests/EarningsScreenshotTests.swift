import Foundation
import Testing
@testable import FleetCheck

@Suite("Reading earnings text")
struct EarningsTextParserTests {
    let parser = EarningsTextParser()

    @Test(arguments: [
        ("12,50", 12.5), ("12.50", 12.5), ("1.234,56", 1234.56), ("1,234.56", 1234.56),
        ("1.234", 1234.0), ("1,234", 1234.0), ("1234,5", 1234.5), ("RON 431.90", 431.9),
        ("1.702,80 lei", 1702.8), ("-3,20", -3.2), ("€45", 45.0), ("1.234.567,00", 1_234_567.0),
    ])
    func parsesAmounts(input: String, expected: Double) {
        #expect(parser.amount(in: input) == expected)
    }

    @Test func findsMoneyButNotCounts() {
        #expect(parser.amounts(in: "Trips  18") == [])
        #expect(parser.amounts(in: "Online  8 h 42 min") == [])
        #expect(parser.amounts(in: "Tips  RON 25.50") == [25.5])
        #expect(parser.amounts(in: "Bacșișuri  41,50 lei") == [41.5])
    }

    @Test("Label and amount on the same row are joined; rows are read top to bottom")
    func groupsRows() {
        let fragments = [
            TextFragment(text: "RON 25.50", minX: 0.8, midY: 0.40, height: 0.02),
            TextFragment(text: "Tips", minX: 0.05, midY: 0.401, height: 0.02),
            TextFragment(text: "Uber", minX: 0.05, midY: 0.05, height: 0.03),
        ]
        #expect(parser.lines(from: fragments) == ["Uber", "Tips  RON 25.50"])
    }

    @Test func parsesEnglishUberDay() {
        let result = parser.parse(lines: [
            "Uber", "Mon, Oct 12", "RON 512.40",
            "Trip earnings  RON 431.90", "Tips  RON 25.50", "Promotions  RON 55.00", "Trips  18", "Online  8 h 42 min",
        ])
        #expect(result.platform == .uber)
        #expect(result.total == 512.4)
        #expect(result.fares == 431.9)
        #expect(result.tips == 25.5)
        #expect(result.bonus == 55)
        #expect(result.trips == 18)
    }

    @Test func parsesRomanianBoltWeek() {
        let result = parser.parse(lines: [
            "Bolt", "Săptămâna 5 - 11 oct.", "1.874,30 lei",
            "Câștiguri din curse  1.702,80 lei", "Bacșișuri  41,50 lei", "Promoții  130,00 lei", "Curse  64",
        ])
        #expect(result.platform == .bolt)
        #expect(result.scope == .week)
        #expect(result.total == 1874.3)
        #expect(result.fares == 1702.8)
        #expect(result.tips == 41.5)
        #expect(result.bonus == 130)
        #expect(result.trips == 64)
    }

    @Test func reportSummary() {
        let result = ScreenshotEarnings(platform: .bolt, scope: .week, total: 1874.3, fares: 1702.8, tips: 41.5, trips: 64)
        #expect(result.summary == "app=Bolt scope=week total=1874.30 fares=1702.80 tips=41.50 bonus=- trips=64")
    }

    @Test("Parts are made to add up to the headline total")
    func normalizes() {
        let missingFares = ScreenshotEarnings(total: 300, tips: 20, bonus: 30).normalized()
        #expect(missingFares.fares == 250)

        let misread = ScreenshotEarnings(total: 300, fares: 999, tips: 20).normalized()
        #expect(misread.fares == 280)

        let tipsTooBig = ScreenshotEarnings(total: 100, tips: 250).normalized()
        #expect(tipsTooBig.fares == 100)
        #expect(tipsTooBig.tips == nil)

        let noTotal = ScreenshotEarnings(fares: 200, tips: 10).normalized()
        #expect(noTotal.total == 210)
    }
}

/// Real Vision OCR on generated screenshots (Scripts/generate_test_screenshots.py), then keyword parsing.
/// Apple Intelligence is off here: the simulator host may not have it, and its output isn't deterministic.
@Suite("Screenshot scanning (Vision OCR)")
struct EarningsScreenshotScannerTests {
    func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "png"))
        return try Data(contentsOf: url)
    }

    @Test func scansUberDarkScreenshot() async throws {
        let result = try await EarningsScreenshotScanner(useAppleIntelligence: false).scan(try fixture("uber_day_en"))
        #expect(result.platform == .uber)
        #expect(result.total == 512.4)
        #expect(result.tips == 25.5)
        #expect(result.bonus == 55)
        #expect(result.fares == 431.9)
        #expect(result.trips == 18)
    }

    @Test func scansRomanianBoltScreenshot() async throws {
        let result = try await EarningsScreenshotScanner(useAppleIntelligence: false).scan(try fixture("bolt_week_ro"))
        #expect(result.platform == .bolt)
        #expect(result.scope == .week)
        #expect(result.total == 1874.3)
        #expect(result.tips == 41.5)
        #expect(result.bonus == 130)
        #expect(result.trips == 64)
    }

    @Test("A trip screen gives the driver's earnings, not what the passenger paid")
    func scansUberTripDetails() async throws {
        let result = try await EarningsScreenshotScanner(useAppleIntelligence: false).scan(try fixture("uber_trip_en"))
        #expect(result.platform == .uber)
        #expect(result.scope == .trip)
        #expect(result.total == 34.2)
        #expect(result.fares == 30.7)
        #expect(result.tips == 3.5)
        #expect(result.trips == 1)
    }

    @Test("Romanian Uber week: points and online time are ignored, the date range means a week")
    func scansRomanianUberWeek() async throws {
        let result = try await EarningsScreenshotScanner(useAppleIntelligence: false).scan(try fixture("uber_week_ro"))
        #expect(result.scope == .week)
        #expect(result.total == 2146.75)
        #expect(result.fares == 1948.25)
        #expect(result.tips == 78.5)
        #expect(result.bonus == 120)
        #expect(result.trips == 71)
    }

    @Test("Net earnings win over gross; commission and cash are ignored")
    func scansBoltGrossAndNet() async throws {
        let result = try await EarningsScreenshotScanner(useAppleIntelligence: false).scan(try fixture("bolt_day_gross_net"))
        #expect(result.platform == .bolt)
        #expect(result.scope == .day)
        #expect(result.total == 318.4)
        #expect(result.tips == 12)
        #expect(result.fares == 306.4)
        #expect(result.trips == 14)
    }

    @Test func keepsTheTextItRead() async throws {
        let result = try await EarningsScreenshotScanner(useAppleIntelligence: false).scan(try fixture("uber_day_en"))
        #expect(result.recognizedLines.contains { $0.contains("Tips") })
    }
}

private final class BundleToken {}
