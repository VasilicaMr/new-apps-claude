import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.money) private var money
    @Query private var shifts: [Shift]
    @Query private var earnings: [Earning]
    @Query private var expenses: [Expense]
    @State private var period = StatsPeriod.week
    @State private var offset = 0
    @State private var selectedBar: Date?

    private var interval: DateInterval { period.interval(offset: offset) }

    /// Stops at the end of today so spread-out costs (insurance, vignette) aren't charged for days still to come.
    private var elapsedInterval: DateInterval {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return DateInterval(start: interval.start, end: max(interval.start, min(interval.end, endOfToday)))
    }

    private var stats: PeriodStats {
        StatsCalculator().stats(in: elapsedInterval,
                                shifts: shifts.filter { !$0.isActive }.map(\.figures),
                                earnings: earnings.map(\.figures),
                                expenses: expenses.map(\.figures))
    }

    var body: some View {
        let stats = stats
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    periodStepper

                    headline(stats)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        KPITile(title: "Earned", value: money.string(stats.earnings), symbol: "banknote",
                                footnote: stats.tips > 0 ? String(localized: "incl. \(money.string(stats.tips)) tips") : nil, iconTint: Theme.warning)
                        KPITile(title: "Costs", value: money.string(stats.expenses), symbol: "cart",
                                footnote: stats.costPerKm.map { "\(money.string($0, decimals: true)) / km" }, iconTint: Theme.negative)
                        KPITile(title: "Hours", value: Formatters.hours(stats.hours), symbol: "clock",
                                iconTint: Color(red: 0.55, green: 0.40, blue: 0.95))
                        KPITile(title: "Kilometers", value: stats.km.kilometers, symbol: "road.lanes",
                                footnote: stats.shiftCount > 0 ? String(localized: "\(stats.shiftCount) shifts") : nil)
                        KPITile(title: "Net per hour", value: stats.netPerHour.map { money.string($0) } ?? "—", symbol: "gauge.with.needle",
                                tint: Theme.color(forNet: stats.netPerHour ?? 0),
                                footnote: stats.earningsPerHour.map { String(localized: "\(money.string($0)) before costs") }, iconTint: Theme.positive)
                        KPITile(title: "Net per km", value: stats.netPerKm.map { money.string($0, decimals: true) } ?? "—", symbol: "speedometer",
                                tint: Theme.color(forNet: stats.netPerKm ?? 0),
                                footnote: stats.trips > 0 ? String(localized: "\(stats.trips) trips") : nil, iconTint: Theme.positive)
                    }

                    if period != .day { chart(stats) }
                    breakdowns(stats)
                }
                .padding()
            }
            .fleetBackground()
            .navigationTitle("Stats")
            .onChange(of: period) { _, _ in
                offset = 0
                selectedBar = nil
            }
        }
    }

    private var periodStepper: some View {
        HStack {
            stepButton("Previous", symbol: "chevron.left") { offset -= 1; selectedBar = nil }
            Spacer()
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Spacer()
            stepButton("Next", symbol: "chevron.right") { offset += 1; selectedBar = nil }
                .disabled(offset >= 0)
        }
    }

    private func stepButton(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.blue)
            .frame(width: 40, height: 40)
            .background(Theme.cardBackground, in: .circle)
            .overlay(Circle().strokeBorder(Theme.cardStroke, lineWidth: 1))
            .shadow(color: Theme.cardShadow, radius: 6, y: 2)
            .buttonStyle(PressableStyle())
    }

    private var title: String {
        let start = interval.start
        switch period {
        case .day: return offset == 0 ? String(localized: "Today") : start.formatted(.dateTime.weekday(.wide).day().month())
        case .week:
            let end = interval.end.addingTimeInterval(-1)
            return offset == 0 ? String(localized: "This week") : "\(start.formatted(.dateTime.day().month())) – \(end.formatted(.dateTime.day().month()))"
        case .month: return start.formatted(.dateTime.month(.wide).year())
        case .year: return start.formatted(.dateTime.year())
        }
    }

    private func headline(_ stats: PeriodStats) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net after costs")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .opacity(0.88)
                Text(money.string(stats.net))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text("\(money.string(stats.earnings)) earned − \(money.string(stats.expenses)) costs")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.22), in: .capsule)
            }
            Spacer(minLength: 0)
            Image(systemName: stats.net < 0 ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 26, weight: .heavy))
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.20), in: .rect(cornerRadius: 16, style: .continuous))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(stats.net < 0 ? Theme.lossGradient : Theme.profitGradient, cornerRadius: 28,
                      shadow: (stats.net < 0 ? Theme.negative : Theme.positive).opacity(0.30))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Chart

    private struct Bar: Identifiable {
        let date: Date
        let net: Double
        let earnings: Double
        var id: Date { date }
    }

    /// Daily bars, or monthly for a year.
    private func bars(_ stats: PeriodStats) -> [Bar] {
        guard period == .year else { return stats.days.map { Bar(date: $0.day, net: $0.net, earnings: $0.earnings) } }
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: stats.days) { calendar.dateInterval(of: .month, for: $0.day)?.start ?? $0.day }
        return byMonth.keys.sorted().map { month in
            let days = byMonth[month] ?? []
            return Bar(date: month, net: days.reduce(0) { $0 + $1.net }, earnings: days.reduce(0) { $0 + $1.earnings })
        }
    }

    private func chart(_ stats: PeriodStats) -> some View {
        let bars = bars(stats)
        let unit: Calendar.Component = period == .year ? .month : .day
        let selected = selectedBar.flatMap { date in bars.first { Calendar.current.isDate($0.date, equalTo: date, toGranularity: unit) } }

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: period == .year ? "Net per month" : "Net per day",
                          subtitle: selected.map { bar -> LocalizedStringKey in
                              "\(bar.date.formatted(period == .year ? .dateTime.month(.wide) : .dateTime.weekday().day().month())): \(money.string(bar.net)) net, \(money.string(bar.earnings)) earned"
                          }
                              ?? "Tap a bar for details")
            Chart(bars) { bar in
                BarMark(x: .value("Date", bar.date, unit: unit), y: .value("Net", bar.net))
                    .foregroundStyle(LinearGradient(colors: bar.net < 0 ? [Theme.negative.opacity(0.8), Theme.negative]
                                                                         : [Color(red: 0.55, green: 0.40, blue: 0.95), Theme.blue],
                                                    startPoint: .top, endPoint: .bottom))
                    .opacity(selected == nil || selected?.id == bar.id ? 1 : 0.35)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: bar.net >= 0 ? 6 : 0, bottomLeadingRadius: bar.net < 0 ? 6 : 0,
                                                      bottomTrailingRadius: bar.net < 0 ? 6 : 0, topTrailingRadius: bar.net >= 0 ? 6 : 0))
                RuleMark(y: .value("Zero", 0)).foregroundStyle(Theme.ink.opacity(0.25)).lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartXSelection(value: $selectedBar)
            .chartXScale(domain: interval.start...interval.end)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.ink.opacity(0.08))
                    AxisValueLabel { if let amount = value.as(Double.self) { Text(money.string(amount)) } }
                }
            }
            .chartXAxis {
                switch period {
                case .week: AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) }
                case .month: AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day()) }
                default: AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) }
                }
            }
            .frame(height: 200)
        }
        .card()
    }

    // MARK: - Breakdowns

    @ViewBuilder
    private func breakdowns(_ stats: PeriodStats) -> some View {
        if !stats.earningsByPlatform.isEmpty {
            BreakdownCard(title: "Earnings by app",
                          rows: stats.earningsByPlatform.sorted { $0.value > $1.value }.map { ($0.key.title, "car.fill", $0.value) })
        }
        if !stats.expensesByCategory.isEmpty {
            BreakdownCard(title: "Where the money went",
                          rows: stats.expensesByCategory.sorted { $0.value > $1.value }.map { ($0.key.title, $0.key.symbol, $0.value) })
        }
        if stats.shiftCount == 0 && stats.earnings == 0 && stats.expenses == 0 {
            ContentUnavailableView("Nothing logged", systemImage: "chart.bar",
                                   description: Text("Start a shift or add earnings and expenses to see your stats."))
        }
    }
}

/// A ranked list with a proportional bar per row.
private struct BreakdownCard: View {
    let title: LocalizedStringKey
    let rows: [(label: String, symbol: String, value: Double)]
    @Environment(\.money) private var money

    var body: some View {
        let total = rows.reduce(0) { $0 + $1.value }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            ForEach(rows, id: \.label) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        IconBadge(symbol: row.symbol, size: 28)
                        Text(row.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(money.string(row.value))
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text((total > 0 ? row.value / total : 0).percentString)
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary).frame(width: 40, alignment: .trailing)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.wash)
                            Capsule().fill(LinearGradient(colors: [Theme.blue, Color(red: 0.55, green: 0.40, blue: 0.95)],
                                                          startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, proxy.size.width * (total > 0 ? row.value / total : 0)))
                        }
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}
