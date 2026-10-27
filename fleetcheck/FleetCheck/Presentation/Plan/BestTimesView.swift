import SwiftUI

/// When driving pays best: earnings per hour for each weekday and part of the day, and which app pays more.
struct BestTimesView: View {
    let plan: MoneyPlan
    @Environment(\.money) private var money

    private var report: BestTimesReport { plan.bestTimes }
    private let calendar = Calendar.current

    /// Weekdays in the order of the user's week (Monday first in Romania).
    private var weekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let best = report.best {
                    bestCard(best)
                    gridCard
                    rankingCard
                    if !report.apps.isEmpty { appsCard }
                } else {
                    ContentUnavailableView("Not enough shifts yet", systemImage: "clock.badge.questionmark",
                                           description: Text("Track your shifts with Start and End and add their earnings. After about 2 weeks DriveCap shows which days and hours pay best, and on which app."))
                        .padding(.top, 60)
                }
            }
            .padding()
        }
        .fleetBackground()
        .navigationTitle("Best times to drive")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "Friday evening"; French and Romanian weekdays are lowercase, so the first letter is capitalized.
    private func name(_ slot: TimeSlot) -> String {
        let name = String(localized: "\(calendar.weekdaySymbols[slot.weekday - 1]) \(slot.part.title.lowercased())",
                          comment: "Weekday and part of the day, e.g. Friday evening")
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    private func bestCard(_ best: SlotRate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pays best").font(.subheadline.weight(.bold)).opacity(0.9)
            Text(verbatim: name(best.slot))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Text("\(best.slot.part.hours) · \(money.string(best.perHour)) an hour")
                .font(.headline.weight(.bold))
            if let app = best.bestApp, let other = Platform.allCases.first(where: { $0 != app && best.perHour($0) != nil }) {
                Text("\(app.title) pays \(money.string(best.perHour(app) ?? 0))/h then, \(other.title) \(money.string(best.perHour(other) ?? 0))/h.")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(Theme.earningsGradient, cornerRadius: 26)
    }

    // MARK: - Week grid

    private var gridCard: some View {
        let top = report.best?.perHour ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Earned per hour", subtitle: "Last 8 weeks, in \(money.currencyCode). Darker pays more.")
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    Color.clear.frame(width: 40, height: 1)
                    ForEach(DayPart.allCases) { part in
                        VStack(spacing: 2) {
                            Image(systemName: part.symbol).font(.subheadline)
                            Text(part.hours).font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(part.title)
                    }
                }
                ForEach(weekdays, id: \.self) { weekday in
                    GridRow {
                        Text(calendar.shortWeekdaySymbols[weekday - 1])
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 40, alignment: .leading)
                        ForEach(DayPart.allCases) { part in
                            cell(report.slots[TimeSlot(weekday: weekday, part: part)], top: top)
                        }
                    }
                }
            }
            Text("Faded squares have less than \(Int(report.minimumHours)) hours of driving, so they're only a hint.")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .card()
    }

    @ViewBuilder
    private func cell(_ rate: SlotRate?, top: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if let rate {
            let trusted = report.isTrusted(rate)
            let strength = top > 0 ? min(1, rate.perHour / top) : 0
            let isBest = rate.slot == report.best?.slot
            Text(rate.perHour.decimal(0))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(trusted && strength > 0.6 ? .white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(PlanColors.times.opacity(trusted ? 0.15 + 0.85 * strength * strength : 0.10), in: shape)
                .overlay(shape.strokeBorder(isBest ? Theme.ink : .clear, lineWidth: 2))
                .opacity(trusted ? 1 : 0.6)
                .accessibilityLabel("\(name(rate.slot)): \(money.string(rate.perHour)) an hour")
        } else {
            Text(verbatim: "–")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Theme.wash.opacity(0.6), in: shape)
                .accessibilityLabel("No driving")
        }
    }

    // MARK: - Ranking

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Top times")
            ForEach(Array(report.ranked.prefix(3).enumerated()), id: \.element.id) { index, rate in
                rankRow("\(index + 1)", rate, tint: PlanColors.times)
            }
            if let slowest = report.slowest {
                Divider()
                Text("Slowest").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSecondary)
                rankRow("↓", slowest, tint: Theme.negative)
            }
        }
        .card()
    }

    private func rankRow(_ badge: String, _ rate: SlotRate, tint: Color) -> some View {
        HStack(spacing: 12) {
            Text(badge)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name(rate.slot)).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(rate.bestApp.map { app -> LocalizedStringKey in "\(rate.slot.part.hours) · \(Formatters.hours(rate.hours)) driven · best on \(app.title)" }
                     ?? "\(rate.slot.part.hours) · \(Formatters.hours(rate.hours)) driven")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text("\(money.string(rate.perHour))/h")
                .font(.system(.body, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Apps

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Uber or Bolt?", subtitle: "All times together")
            ForEach(report.apps) { app in
                HStack {
                    Text(app.platform.title).font(.body.weight(.bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let perHour = app.perHour {
                            Text("\(money.string(perHour)) an hour").font(.system(.body, design: .rounded, weight: .heavy))
                        }
                        if let perKm = app.perKm {
                            Text("\(perKm.decimal(2)) \(money.currencyCode) per km").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
            Text("When you run both apps in one shift, each gets the hours in proportion to what it paid.")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .card()
    }
}
