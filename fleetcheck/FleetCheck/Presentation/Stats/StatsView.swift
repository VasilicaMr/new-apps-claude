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
                                footnote: stats.tips > 0 ? "incl. \(money.string(stats.tips)) tips" : nil)
                        KPITile(title: "Costs", value: money.string(stats.expenses), symbol: "cart",
                                footnote: stats.costPerKm.map { "\(money.string($0, decimals: true)) / km" })
                        KPITile(title: "Hours", value: Formatters.hours(stats.hours), symbol: "clock",
                                footnote: stats.movingShare.map { "\($0.percentString) driving" })
                        KPITile(title: "Kilometers", value: stats.km.kilometers, symbol: "road.lanes",
                                footnote: stats.shiftCount > 0 ? "\(stats.shiftCount) shift\(stats.shiftCount == 1 ? "" : "s")" : nil)
                        KPITile(title: "Net per hour", value: stats.netPerHour.map { money.string($0) } ?? "—", symbol: "gauge.with.needle",
                                tint: Theme.color(forNet: stats.netPerHour ?? 0),
                                footnote: stats.earningsPerHour.map { "\(money.string($0)) before costs" })
                        KPITile(title: "Net per km", value: stats.netPerKm.map { money.string($0, decimals: true) } ?? "—", symbol: "speedometer",
                                tint: Theme.color(forNet: stats.netPerKm ?? 0),
                                footnote: stats.trips > 0 ? "\(stats.trips) trips" : nil)
                    }

                    if period != .day { chart(stats) }
                    breakdowns(stats)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
            .onChange(of: period) { _, _ in
                offset = 0
                selectedBar = nil
            }
        }
    }

    private var periodStepper: some View {
        HStack {
            Button("Previous", systemImage: "chevron.left") { offset -= 1; selectedBar = nil }
                .labelStyle(.iconOnly)
            Spacer()
            Text(title).font(.headline).contentTransition(.numericText())
            Spacer()
            Button("Next", systemImage: "chevron.right") { offset += 1; selectedBar = nil }
                .labelStyle(.iconOnly)
                .disabled(offset >= 0)
        }
        .padding(.horizontal, 4)
    }

    private var title: String {
        let start = interval.start
        switch period {
        case .day: return offset == 0 ? "Today" : start.formatted(.dateTime.weekday(.wide).day().month())
        case .week:
            let end = interval.end.addingTimeInterval(-1)
            return offset == 0 ? "This week" : "\(start.formatted(.dateTime.day().month())) – \(end.formatted(.dateTime.day().month()))"
        case .month: return start.formatted(.dateTime.month(.wide).year())
        case .year: return start.formatted(.dateTime.year())
        }
    }

    private func headline(_ stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Net after costs").font(.subheadline).foregroundStyle(.secondary)
            Text(money.string(stats.net))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.color(forNet: stats.net))
                .contentTransition(.numericText())
            Text("\(money.string(stats.earnings)) earned − \(money.string(stats.expenses)) costs")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
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
                          subtitle: selected.map { "\($0.date.formatted(period == .year ? .dateTime.month(.wide) : .dateTime.weekday().day().month())): \(money.string($0.net)) net, \(money.string($0.earnings)) earned" }
                              ?? "Tap a bar for details")
            Chart(bars) { bar in
                BarMark(x: .value("Date", bar.date, unit: unit), y: .value("Net", bar.net))
                    .foregroundStyle(Theme.accent.opacity(selected == nil || selected?.id == bar.id ? 1 : 0.35))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: bar.net >= 0 ? 4 : 0, bottomLeadingRadius: bar.net < 0 ? 4 : 0,
                                                      bottomTrailingRadius: bar.net < 0 ? 4 : 0, topTrailingRadius: bar.net >= 0 ? 4 : 0))
                RuleMark(y: .value("Zero", 0)).foregroundStyle(.secondary.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartXSelection(value: $selectedBar)
            .chartXScale(domain: interval.start...interval.end)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
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
    let title: String
    let rows: [(label: String, symbol: String, value: Double)]
    @Environment(\.money) private var money

    var body: some View {
        let total = rows.reduce(0) { $0 + $1.value }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            ForEach(rows, id: \.label) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(row.label, systemImage: row.symbol).font(.subheadline)
                        Spacer()
                        Text(money.string(row.value)).font(.subheadline.weight(.semibold))
                        Text((total > 0 ? row.value / total : 0).percentString)
                            .font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                    }
                    GeometryReader { proxy in
                        Capsule().fill(Theme.accent)
                            .frame(width: max(4, proxy.size.width * (total > 0 ? row.value / total : 0)))
                    }
                    .frame(height: 6)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}
