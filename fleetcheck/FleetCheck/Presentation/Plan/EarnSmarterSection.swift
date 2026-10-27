import SwiftData
import SwiftUI

/// The three Earn smarter tools, each opened from its column on Home.
enum PlanTool: Hashable {
    case carCost, goal, bestTimes
}

/// Builds the plan from live data, so every Earn smarter screen updates as soon as something is logged or edited.
struct WithMoneyPlan<Content: View>: View {
    @Query private var shifts: [Shift]
    @Query private var earnings: [Earning]
    @Query private var expenses: [Expense]
    @Query private var cars: [Car]
    @AppStorage(SettingsKeys.weeklyGoal) private var weeklyGoal = 0.0
    @ViewBuilder let content: (MoneyPlan) -> Content

    var body: some View {
        content(MoneyPlan(shifts: shifts, earnings: earnings, expenses: expenses, car: cars.first, weeklyGoal: weeklyGoal))
    }
}

/// Home's "Earn smarter" section: minimum fare per km, the weekly goal and the best time to drive, side by side.
/// Each column shows one big number and a plain sentence; tapping it explains how it's worked out.
/// For free drivers the columns are a preview: the numbers are blurred and a tap opens the paywall.
struct EarnSmarterSection: View {
    let plan: MoneyPlan
    var isLocked = false
    var unlock: () -> Void = {}
    @Environment(\.money) private var money
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Earn smarter", subtitle: "Tap a column to see how it's worked out")
            // Three columns get too narrow for very large text, so they stack instead.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                if isLocked {
                    Button(action: unlock) { carColumn }
                    Button(action: unlock) { goalColumn }
                    Button(action: unlock) { timesColumn }
                } else {
                    NavigationLink(value: PlanTool.carCost) { carColumn }
                    NavigationLink(value: PlanTool.goal) { goalColumn }
                    NavigationLink(value: PlanTool.bestTimes) { timesColumn }
                }
            }
            .environment(\.planLocked, isLocked)
            .buttonStyle(PressableStyle())
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currency: String { money.currencyCode }

    private var carColumn: some View {
        let cost = plan.carCost
        return Group {
            if cost.isSetUp {
                PlanColumn(title: "Minimum fare", symbol: "car.side.fill", tint: PlanColors.car,
                           value: cost.costPerKm.decimal(2), unit: String(localized: "\(currency) per km"),
                           caption: String(localized: "Below this per km you lose money."))
            } else {
                PlanColumn(title: "Car cost", symbol: "car.side.fill", tint: PlanColors.car,
                           value: String(localized: "Set up"), unit: String(localized: "your car's real cost"), valueTint: PlanColors.car,
                           caption: cost.costPerKm > 0
                               ? String(localized: "Fuel alone is \(cost.costPerKm.decimal(2)) \(currency)/km. Add leasing, tyres and service.")
                               : String(localized: "Add leasing, tyres and service to find your minimum fare."))
            }
        }
        .accessibilityIdentifier("plan.carCost")
    }

    private var goalColumn: some View {
        Group {
            if let goal = plan.goal {
                if goal.isReached {
                    PlanColumn(title: "Weekly goal", symbol: "flag.checkered", tint: PlanColors.goal,
                               value: String(localized: "Done"), unit: String(localized: "goal reached"), valueTint: PlanColors.goal, progress: 1,
                               caption: String(localized: "You kept \(money.string(goal.net)) of \(money.string(goal.goal))."))
                } else {
                    PlanColumn(title: "Weekly goal", symbol: "flag.checkered", tint: PlanColors.goal,
                               value: goal.remaining.decimal(0), unit: String(localized: "\(currency) to go"), progress: goal.fraction,
                               caption: goalCaption(goal))
                }
            } else {
                PlanColumn(title: "Weekly goal", symbol: "flag.checkered", tint: PlanColors.goal,
                           value: String(localized: "Set"), unit: String(localized: "a weekly goal"), valueTint: PlanColors.goal,
                           caption: String(localized: "Pick what to keep this week and see the hours to go."))
            }
        }
        .accessibilityIdentifier("plan.goal")
    }

    private func goalCaption(_ goal: GoalProgress) -> String {
        guard let hours = goal.hoursNeeded else { return String(localized: "of \(money.string(goal.goal)) · \(goal.daysLeft) days left") }
        let more = Int(hours.rounded(.up))
        guard let weekday = goal.rateWeekday else { return String(localized: "About \(more) h more at your usual rate.") }
        return String(localized: "About \(more) h more at your \(Calendar.current.weekdaySymbols[weekday - 1]) rate.")
    }

    private var timesColumn: some View {
        Group {
            if let best = plan.bestTimes.best {
                PlanColumn(title: "Best time", symbol: "clock.badge.checkmark.fill", tint: PlanColors.times,
                           value: Calendar.current.shortWeekdaySymbols[best.slot.weekday - 1],
                           unit: "\(best.slot.part.title.lowercased()) \(best.slot.part.hours)",
                           caption: best.bestApp.map { String(localized: "\(money.string(best.perHour)) an hour, best on \($0.title).") }
                               ?? String(localized: "\(money.string(best.perHour)) an hour."))
            } else {
                PlanColumn(title: "Best time", symbol: "clock.badge.checkmark.fill", tint: PlanColors.times,
                           value: String(localized: "Soon"), unit: String(localized: "needs more shifts"), valueTint: PlanColors.times,
                           caption: String(localized: "Shows after about 2 weeks of shifts with earnings."))
            }
        }
        .accessibilityIdentifier("plan.bestTimes")
    }
}

enum PlanColors {
    static let car = Color(red: 0.45, green: 0.40, blue: 0.78)
    static let goal = Theme.positive
    static let times = Color(red: 0.95, green: 0.52, blue: 0.20)
}

/// One column: what it is, one big number, its unit, and a sentence saying what it means.
struct PlanColumn: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    let value: String
    let unit: String
    var valueTint: Color = Theme.ink
    var progress: Double?
    let caption: String

    @Environment(\.planLocked) private var isLocked

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            IconBadge(symbol: symbol, tint: tint, size: 34)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(valueTint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .padding(.top, 2)
                .blur(radius: isLocked ? 7 : 0)
                .accessibilityHidden(isLocked)
            Text(unit)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let progress {
                ProgressView(value: progress).tint(tint)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(Theme.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .blur(radius: isLocked ? 4 : 0)
                .accessibilityHidden(isLocked)
            Spacer(minLength: 4)
            if isLocked {
                ProBadge()
            } else {
                HStack(spacing: 3) {
                    Text("See how")
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

extension EnvironmentValues {
    /// Earn smarter columns shown as a Pro preview.
    @Entry var planLocked = false
}

extension Double {
    /// A plain number with a fixed number of decimals, for figures shown next to their currency.
    func decimal(_ digits: Int) -> String { formatted(.number.precision(.fractionLength(digits))) }
}
