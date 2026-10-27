import Foundation
import Testing
@testable import FleetCheck

@Suite("Reminders")
struct ReminderPlannerTests {
    let calendar = Calendar(identifier: .gregorian)
    func date(_ month: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: month, day: day))! }

    var planner: ReminderPlanner { ReminderPlanner(calendar: calendar) }

    @Test func urgencyByDate() {
        let today = date(10, 12)
        #expect(planner.status(of: DueRule(dueDate: date(12, 30)), today: today, odometerKm: 0).urgency == .ok)
        #expect(planner.status(of: DueRule(dueDate: date(10, 20)), today: today, odometerKm: 0).daysLeft == 8)
        #expect(planner.status(of: DueRule(dueDate: date(10, 20)), today: today, odometerKm: 0).urgency == .soon)
        #expect(planner.status(of: DueRule(dueDate: date(10, 12)), today: today, odometerKm: 0).urgency == .soon)
        #expect(planner.status(of: DueRule(dueDate: date(10, 11)), today: today, odometerKm: 0).urgency == .overdue)
    }

    @Test("Whichever comes first: date or kilometers")
    func urgencyByKm() {
        let rule = DueRule(dueDate: date(12, 30), dueKm: 150_000)
        #expect(planner.status(of: rule, today: date(10, 12), odometerKm: 148_000).urgency == .ok)
        #expect(planner.status(of: rule, today: date(10, 12), odometerKm: 149_500).urgency == .soon)
        #expect(planner.status(of: rule, today: date(10, 12), odometerKm: 150_100).urgency == .overdue)
    }

    @Test("Renewing early keeps the insurance cycle; renewing late starts from today")
    func renewal() {
        let rule = DueRule(dueDate: date(10, 20), repeatMonths: 12)
        #expect(planner.nextRule(after: rule, doneDate: date(10, 12), odometerKm: 0).dueDate == calendar.date(from: DateComponents(year: 2027, month: 10, day: 20)))
        #expect(planner.nextRule(after: rule, doneDate: date(11, 2), odometerKm: 0).dueDate == calendar.date(from: DateComponents(year: 2027, month: 11, day: 2)))
    }

    @Test func oilChangeRenewsFromCurrentOdometer() {
        let rule = DueRule(dueKm: 150_000, repeatKm: 15_000)
        #expect(planner.nextRule(after: rule, doneDate: date(10, 12), odometerKm: 149_200).dueKm == 164_200)
    }
}

@Suite("CSV export")
struct CSVExporterTests {
    let exporter = CSVExporter(timeZone: TimeZone(identifier: "UTC")!)

    @Test func escapesSpecialCharacters() {
        #expect(exporter.escape("plain") == "plain")
        #expect(exporter.escape("Petrom, Calea Victoriei") == "\"Petrom, Calea Victoriei\"")
        #expect(exporter.escape("the \"good\" one") == "\"the \"\"good\"\" one\"")
    }

    @Test func expensesTable() {
        let csv = exporter.expenses([
            .init(date: Date(timeIntervalSince1970: 0), category: .fuel, amount: 250.5, liters: 34, odometerKm: 148_000, note: "OMV, A1"),
        ])
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[0] == "date,category,amount,liters,odometer_km,note")
        #expect(lines[1] == "1970-01-01T00:00:00Z,Fuel,250.50,34.00,148000.00,\"OMV, A1\"")
    }

    @Test func shiftHoursAreComputed() {
        let start = Date(timeIntervalSince1970: 0)
        let csv = exporter.shifts([.init(start: start, end: start.addingTimeInterval(9000), distanceKm: 80, earnings: 300, note: "")])
        #expect(csv.contains(",2.50,80.00,300.00,"))
    }
}
