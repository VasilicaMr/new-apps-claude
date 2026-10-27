import SwiftUI

/// The weekly goal: how much is kept so far, what's left, and how many hours that takes at the best day's rate.
struct GoalView: View {
    let plan: MoneyPlan
    @AppStorage(SettingsKeys.weeklyGoal) private var weeklyGoal = 0.0
    @Environment(\.money) private var money

    private static let presets: [Double] = [1_500, 2_000, 2_500, 3_000]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let goal = plan.goal {
                    progressCard(goal)
                    daysCard(goal)
                } else {
                    Text("Set what you want to keep each week, after costs. DriveCap shows how much is left and about how many hours it takes.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                goalPicker
                Text("The goal counts what you keep: earnings minus costs. Hours are worked out from your last 8 weeks.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .fleetBackground()
        .navigationTitle("Weekly goal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func progressCard(_ goal: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: goal.fraction)
                        .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(goal.fraction.percentString)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                }
                .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.isReached ? "Goal reached" : "To go")
                        .font(.subheadline.weight(.bold))
                        .opacity(0.9)
                    Text(goal.isReached ? money.string(goal.net) : money.string(goal.remaining))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("Kept \(money.string(goal.net)) of \(money.string(goal.goal))")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Text(planSentence(goal))
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(Theme.profitGradient, cornerRadius: 26)
    }

    private func planSentence(_ goal: GoalProgress) -> String {
        if goal.isReached { return String(localized: "Well done. Anything more this week is extra.") }
        guard let hours = goal.hoursNeeded, let rate = goal.rate else {
            return String(localized: "\(goal.daysLeft) days left. Track a few shifts and DriveCap can tell you the hours it takes.")
        }
        let more = Int(hours.rounded(.up)), perHour = money.string(rate)
        let plan = if let weekday = goal.rateWeekday {
            String(localized: "About \(more) more hours at your \(Calendar.current.weekdaySymbols[weekday - 1]) rate (\(perHour) an hour after costs).")
        } else {
            String(localized: "About \(more) more hours at your usual rate (\(perHour) an hour after costs).")
        }
        return plan + " " + String(localized: "\(goal.daysLeft) days left this week.")
    }

    /// The week's days: what was kept on the past ones, and the usual hourly rate for the ones to come.
    private func daysCard(_ goal: GoalProgress) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: plan.week.interval.start) }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "This week, day by day")
            ForEach(days, id: \.self) { day in
                let weekday = calendar.component(.weekday, from: day)
                HStack {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.body.weight(calendar.isDate(day, inSameDayAs: today) ? .heavy : .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if day <= today {
                        let net = plan.week.days.first { calendar.isDate($0.day, inSameDayAs: day) }?.net ?? 0
                        Text(money.string(net))
                            .font(.system(.body, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.color(forNet: net))
                    } else if let rate = plan.weekdayRates[weekday] {
                        Text("usually \(money.string(rate))/h")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(weekday == goal.rateWeekday ? PlanColors.goal : Theme.inkSecondary)
                    } else {
                        Text("no data yet").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .card()
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your goal", subtitle: "What you want to keep each week")
            HStack {
                Text(money.currencyCode).font(.headline).foregroundStyle(Theme.inkSecondary)
                TextField("Amount", value: $weeklyGoal, format: .number.precision(.fractionLength(0)))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("goal.amount")
            }
            .padding(12)
            .background(Theme.wash, in: .rect(cornerRadius: 14, style: .continuous))
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.self) { preset in
                    Button(preset.decimal(0)) { weeklyGoal = preset }
                        .buttonStyle(CapsuleButtonStyle(tint: PlanColors.goal, filled: weeklyGoal == preset, compact: true))
                }
            }
            if weeklyGoal > 0 {
                Button("Remove goal", role: .destructive) { weeklyGoal = 0 }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .card()
    }
}
