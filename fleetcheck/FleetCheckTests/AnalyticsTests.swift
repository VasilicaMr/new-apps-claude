import Foundation
import Testing
@testable import FleetCheck

@Suite("Fleet analytics")
struct AnalyticsTests {
    @Test("Recurring expenses are spread over the period they cover")
    func amortization() {
        let analyzer = FinancialAnalyzer()
        let insurance = Expense(id: "e", vehicleId: "v", date: TestData.date("2026-01-01"), category: .insurance, amount: 730, note: "")
        let tenDays = DateRange(start: TestData.date("2026-03-01"), end: TestData.date("2026-03-11"))
        #expect(abs(analyzer.amortizedAmount(of: insurance, in: tenDays) - 20) < 0.01)

        let fine = Expense(id: "f", vehicleId: "v", date: TestData.date("2026-03-05"), category: .fines, amount: 116, note: "")
        #expect(analyzer.amortizedAmount(of: fine, in: tenDays) == 116)
        #expect(analyzer.amortizedAmount(of: fine, in: DateRange(start: TestData.date("2026-04-01"), end: TestData.date("2026-05-01"))) == 0)

        let salary = Expense(id: "s", vehicleId: "v", date: TestData.date("2026-03-06"), category: .driverWages, amount: 1_200, note: "")
        #expect(abs(analyzer.amortizedAmount(of: salary, in: tenDays) - 200) < 0.01) // 5 of 30 days
    }

    @Test func lastDaysRangeIncludesAsOfDay() {
        let range = DateRange.lastDays(30, endingOn: TestData.date("2026-10-11"))
        #expect(range.contains(TestData.date("2026-10-11")))
        #expect(range.contains(TestData.date("2026-09-12")))
        #expect(!range.contains(TestData.date("2026-09-11")))
        #expect(range.days == 30)
    }

    @Test("Fleet totals equal the sum of vehicle reports")
    func totalsAddUp() async throws {
        let snapshot = try await TestData.loadSnapshot()
        let report = FleetAnalyzer().report(for: snapshot, period: .quarter)
        let revenue = report.vehicles.reduce(0) { $0 + $1.financials.revenue }
        #expect(abs(report.financials.revenue - revenue) < 0.01)
        let monthlyRevenue = report.monthly.reduce(0) { $0 + $1.financials.revenue }
        #expect(abs(monthlyRevenue - revenue) < 0.01)
    }

    @Test("Insights find the stories baked into the mock data")
    func insightsDetectScenarios() async throws {
        let snapshot = try await TestData.loadSnapshot()
        let report = FleetAnalyzer().report(for: snapshot, period: .month)
        let insights = InsightsEngine().insights(for: report, snapshot: snapshot) { "\($0)" }
        let ids = Set(insights.map(\.id))

        #expect(ids.contains("veh-006-replace"), "old Transit should be flagged for replacement")
        #expect(ids.contains("veh-006-dtc"))
        #expect(ids.contains("veh-007-idle-days"), "Kangoo is underused")
        #expect(ids.contains("veh-003-fuel"), "Octavia burns too much diesel")
        #expect(ids.contains("veh-002-harsh"), "Logan #2 driver brakes hard")
        #expect(ids.contains("veh-005-due-insurance"))
        #expect(insights.first?.severity == .critical)
    }
}
