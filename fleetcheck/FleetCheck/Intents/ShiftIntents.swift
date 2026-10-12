import AppIntents
import Foundation
import SwiftData

/// Starting GPS needs the app in the foreground (we only ask for "While Using" permission),
/// so this intent opens FleetCheck.
struct StartShiftIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Shift"
    static let description = IntentDescription("Starts tracking kilometers and time for a new shift.")
    static let openAppWhenRun = true

    @Dependency private var shiftStore: ShiftStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if shiftStore.isOnShift { return .result(dialog: "You're already on shift.") }
        shiftStore.startShift()
        return .result(dialog: "Shift started. Drive safe!")
    }
}

struct TodayEarningsIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Earnings"
    static let description = IntentDescription("Tells you what you earned today, your costs and kilometers.")

    @Dependency private var container: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = container.mainContext
        let interval = StatsPeriod.day.interval(containing: .now)
        let stats = StatsCalculator().stats(
            in: interval,
            shifts: ((try? context.fetch(FetchDescriptor<Shift>())) ?? []).map(\.figures),
            earnings: ((try? context.fetch(FetchDescriptor<Earning>())) ?? []).map(\.figures),
            expenses: ((try? context.fetch(FetchDescriptor<Expense>())) ?? []).map(\.figures))
        let money = MoneyFormatter(currencyCode: UserDefaults.standard.string(forKey: SettingsKeys.currencyCode) ?? MoneyFormatter.defaultCurrencyCode)
        let text = stats.shiftCount == 0 && stats.earnings == 0
            ? "Nothing logged today yet."
            : "Today you earned \(money.string(stats.earnings)), spent \(money.string(stats.expenses)) and drove \(stats.km.kilometers). Net \(money.string(stats.net))."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct FleetCheckShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartShiftIntent(),
                    phrases: ["Start my shift in \(.applicationName)", "Start shift in \(.applicationName)"],
                    shortTitle: "Start Shift", systemImageName: "play.circle.fill")
        AppShortcut(intent: EndShiftIntent(),
                    phrases: ["End my shift in \(.applicationName)", "Stop shift in \(.applicationName)"],
                    shortTitle: "End Shift", systemImageName: "stop.circle.fill")
        AppShortcut(intent: TodayEarningsIntent(),
                    phrases: ["How much did I make today in \(.applicationName)", "Today's earnings in \(.applicationName)"],
                    shortTitle: "Today's Earnings", systemImageName: "banknote.fill")
    }
}
