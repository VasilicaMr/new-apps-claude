import Foundation
import FoundationModels
import SwiftData

// Tools the on-device model can call. Every number it says comes from these, computed by DriverData;
// the model only chooses what to look up and phrases the answer.

/// Things the tools did, so the chat can show them as cards with Undo.
@MainActor
final class AssistantActionLog {
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let model: any PersistentModel
    }

    private(set) var actions: [Action] = []

    func record(_ title: String, _ model: any PersistentModel) { actions.append(Action(title: title, model: model)) }
    func drain() -> [Action] { defer { actions.removeAll() }; return actions }
}

@Generable
enum PeriodArgument {
    case day, week, month, year

    var period: StatsPeriod {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }
}

struct GetStatsTool: Tool {
    let data: DriverData
    let name = "getStats"
    let description = "Earnings, costs, net profit, hours, kilometers, trips, net per hour and per km, earnings by app and costs by category for a day, week, month or year."

    @Generable
    struct Arguments {
        @Guide(description: "Length of the period")
        var period: PeriodArgument
        @Guide(description: "0 for the current period, -1 for the previous one (yesterday, last week…), -2 before that", .range(-24...0))
        var offset: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let stats = data.stats(arguments.period.period, offset: arguments.offset)
            var text = data.describe(stats, label: data.label(arguments.period.period, arguments.offset))
            if !stats.earningsByPlatform.isEmpty {
                text += "\nBy app: " + stats.earningsByPlatform.sorted { $0.value > $1.value }
                    .map { "\($0.key.title) \(data.money.string($0.value))" }.joined(separator: ", ")
            }
            if !stats.expensesByCategory.isEmpty {
                text += "\nCosts: " + stats.expensesByCategory.sorted { $0.value > $1.value }
                    .map { "\($0.key.title) \(data.money.string($0.value))" }.joined(separator: ", ")
            }
            if stats.tips > 0 { text += "\nTips: \(data.money.string(stats.tips)). Trips: \(stats.trips)." }
            return text
        }
    }
}

struct GetInsightsTool: Tool {
    let data: DriverData
    let name = "getInsights"
    let description = "Trends and advice: change in net per hour vs last week, the weekday that pays best, the biggest cost, shifts missing earnings, papers that are due."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { data.insights().map(\.text).joined(separator: "\n") }
    }
}

struct GetRemindersTool: Tool {
    let data: DriverData
    let name = "getReminders"
    let description = "Due dates for ITP inspection, RCA/CASCO insurance, road vignette, oil change, licence and other car paperwork, plus the odometer."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let items = data.reminderStatuses()
            let odometer = "Odometer: \(data.car.odometerKm.kilometers)."
            guard !items.isEmpty else { return "No reminders set. " + odometer }
            return items.map { "\($0.reminder.title): \(data.dueText($0.reminder, $0.status))" }.joined(separator: "\n") + "\n" + odometer
        }
    }
}

struct GetRecentEntriesTool: Tool {
    let data: DriverData
    let name = "getRecentEntries"
    let description = "The most recent shifts, earnings or expenses, newest first, with dates and amounts."

    @Generable
    enum Kind { case shifts, earnings, expenses }

    @Generable
    struct Arguments {
        var kind: Kind
        @Guide(description: "How many entries", .range(1...10))
        var count: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let money = data.money
            let date = { (date: Date) in date.formatted(.dateTime.weekday(.abbreviated).day().month()) }
            let lines: [String] = switch arguments.kind {
            case .shifts:
                data.shifts().filter { !$0.isActive }.prefix(arguments.count).map {
                    "\(date($0.start)): \(Formatters.duration($0.duration)), \($0.distanceKm.kilometers), earned \(money.string($0.earningsTotal))"
                }
            case .earnings:
                data.earnings().prefix(arguments.count).map { "\(date($0.date)): \($0.platform.title) \(money.string($0.total, decimals: true))" }
            case .expenses:
                data.expenses().prefix(arguments.count).map {
                    "\(date($0.date)): \($0.category.title) \(money.string($0.amount, decimals: true))\($0.note.isEmpty ? "" : " (\($0.note))")"
                }
            }
            return lines.isEmpty ? "None logged yet." : lines.joined(separator: "\n")
        }
    }
}

@Generable
enum ExpenseCategoryArgument {
    case fuel, charging, carWash, maintenance, repair, tyres, insurance, roadTax, leasing, parking, tolls, fines, phone, other

    var category: ExpenseCategory { ExpenseCategory(rawValue: String(describing: self)) ?? .other }
}

struct AddExpenseTool: Tool {
    let data: DriverData
    let log: AssistantActionLog
    let name = "addExpense"
    let description = "Saves a cost the driver mentions (fuel, car wash, parking, repair…). Call it right away when the driver says they paid for something."

    @Generable
    struct Arguments {
        var category: ExpenseCategoryArgument
        @Guide(description: "Amount paid, as a plain number")
        var amount: Double
        @Guide(description: "Liters of fuel or kWh charged; 0 if not said")
        var liters: Double
        @Guide(description: "Station, garage or short note; empty if none")
        var note: String
        @Guide(description: "0 for today, 1 for yesterday", .range(0...30))
        var daysAgo: Int
    }

    func call(arguments: Arguments) async throws -> String {
        guard arguments.amount > 0 else { return "Not saved: the amount is missing. Ask the driver how much it was." }
        return await MainActor.run {
            let draft = ExpenseDraft(category: arguments.category.category, amount: arguments.amount,
                                     liters: arguments.liters > 0 ? arguments.liters : nil, note: arguments.note, daysAgo: arguments.daysAgo)
            let expense = data.add(draft)
            let title = data.describe(.expense(draft))
            log.record(String(localized: "Added expense: \(title)"), expense)
            return "Saved expense: \(title)."
        }
    }
}

@Generable
enum PlatformArgument {
    case uber, bolt, freenow, other

    var platform: Platform {
        switch self {
        case .uber: .uber
        case .bolt: .bolt
        case .freenow: .freeNow
        case .other: .other
        }
    }
}

struct AddEarningsTool: Tool {
    let data: DriverData
    let log: AssistantActionLog
    let name = "addEarnings"
    let description = "Saves money the driver earned from a ride-sharing app. Call it right away when the driver says how much they made."

    @Generable
    struct Arguments {
        var app: PlatformArgument
        @Guide(description: "Fares / trip earnings, as a plain number")
        var fares: Double
        @Guide(description: "Tips; 0 if not said")
        var tips: Double
        @Guide(description: "Promotions or bonus; 0 if not said")
        var bonus: Double
        @Guide(description: "Number of trips; 0 if not said", .range(0...200))
        var trips: Int
        @Guide(description: "0 for today, 1 for yesterday", .range(0...30))
        var daysAgo: Int
    }

    func call(arguments: Arguments) async throws -> String {
        guard arguments.fares + arguments.tips + arguments.bonus > 0 else { return "Not saved: no amount. Ask the driver how much they earned." }
        return await MainActor.run {
            let draft = EarningDraft(platform: arguments.app.platform, fares: arguments.fares, tips: arguments.tips,
                                     bonus: arguments.bonus, trips: arguments.trips, daysAgo: arguments.daysAgo)
            let earning = data.add(draft)
            let title = data.describe(.earning(draft))
            log.record(String(localized: "Added earnings: \(title)"), earning)
            return "Saved earnings: \(title)" + (earning.shift == nil ? "." : ", linked to the shift on \(earning.date.formatted(date: .abbreviated, time: .omitted)).")
        }
    }
}
