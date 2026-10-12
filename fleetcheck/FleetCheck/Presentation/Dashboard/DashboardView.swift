import Charts
import SwiftUI

struct DashboardView: View {
    @Binding var selectedTab: AppTab
    @Environment(FleetStore.self) private var store
    @Environment(LiveTrackingStore.self) private var live

    var body: some View {
        NavigationStack {
            LoadingStateView(state: store.state, retry: store.reload) {
                if let report = store.report, let snapshot = store.snapshot {
                    content(report: report, snapshot: snapshot)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(store.snapshot?.company.name ?? "FleetCheck")
            .navigationDestination(for: Vehicle.self) { VehicleDetailView(vehicleId: $0.id) }
        }
    }

    private func content(report: FleetReport, snapshot: FleetSnapshot) -> some View {
        @Bindable var store = store
        let money = store.money
        let totals = report.financials
        return ScrollView {
            VStack(spacing: 16) {
                PeriodPicker(period: $store.period)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    KPITile(title: "Revenue", value: money.string(totals.revenue, compact: true), symbol: "arrow.down.circle",
                            footnote: "\(report.distanceKm.kilometers) driven")
                    KPITile(title: "Costs", value: money.string(totals.totalCost, compact: true), symbol: "arrow.up.circle",
                            tint: .primary, footnote: "incl. \(money.string(totals.depreciation, compact: true)) depreciation")
                    KPITile(title: "Net profit", value: money.string(totals.profit, compact: true), symbol: "chart.line.uptrend.xyaxis",
                            tint: totals.profit >= 0 ? Theme.positive : Theme.negative,
                            footnote: "\(totals.margin.percentString) margin")
                    KPITile(title: "Fleet value", value: money.string(report.fleetValue, compact: true), symbol: "car.2",
                            tint: .primary, footnote: "\((report.fleetValue / max(report.purchaseValue, 1)).percentString) of purchase price")
                    KPITile(title: "On the road now", value: "\(movingCount(snapshot))/\(snapshot.vehicles.count)",
                            symbol: "location.fill", tint: .green, footnote: "live")
                    KPITile(title: "Utilization", value: report.averageUtilization.percentString, symbol: "calendar",
                            tint: .primary, footnote: "days worked")
                }

                monthlyChart(report.monthly, money: money)
                attentionCard(snapshot: snapshot, money: money)
                rankingCard(report: report, money: money)
                dueCard(report: report, snapshot: snapshot)
            }
            .padding()
        }
        .refreshable { await store.reload() }
    }

    private func movingCount(_ snapshot: FleetSnapshot) -> Int {
        snapshot.vehicles.filter { LiveStatus(vehicle: $0, position: live.positions[$0.id]) == .moving }.count
    }

    private func monthlyChart(_ monthly: [MonthlyFinancials], money: MoneyFormatter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Revenue vs costs", subtitle: "Per month, all vehicles")
            Chart {
                ForEach(monthly) { row in
                    BarMark(x: .value("Month", row.month, unit: .month), y: .value("Amount", row.financials.revenue))
                        .foregroundStyle(by: .value("Type", "Revenue"))
                        .position(by: .value("Type", "Revenue"))
                    BarMark(x: .value("Month", row.month, unit: .month), y: .value("Amount", row.financials.totalCost))
                        .foregroundStyle(by: .value("Type", "Costs"))
                        .position(by: .value("Type", "Costs"))
                }
            }
            .chartForegroundStyleScale(["Revenue": Theme.accent, "Costs": Color.orange])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let amount = value.as(Double.self) { Text(money.string(amount, compact: true)) } }
                }
            }
            .frame(height: 200)
        }
        .card()
    }

    private func attentionCard(snapshot: FleetSnapshot, money: MoneyFormatter) -> some View {
        let urgent = store.insights.filter { $0.severity >= .warning }.prefix(3)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "Needs your attention", subtitle: "\(store.insights.filter { $0.severity >= .warning }.count) open items")
                Button("All") { selectedTab = .insights }.font(.subheadline)
            }
            if urgent.isEmpty {
                Label("All good — nothing urgent.", systemImage: "checkmark.circle").foregroundStyle(.green)
            }
            ForEach(Array(urgent)) { insight in
                InsightRow(insight: insight, money: money)
                if insight.id != urgent.last?.id { Divider() }
            }
        }
        .card()
    }

    private func rankingCard(report: FleetReport, money: MoneyFormatter) -> some View {
        let ranked = report.vehicles.sorted { $0.financials.profit > $1.financials.profit }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Profit by vehicle", subtitle: "Last \(report.period.rawValue) days, after all costs")
            Chart(ranked) { row in
                BarMark(x: .value("Profit", row.financials.profit), y: .value("Vehicle", row.vehicle.plate))
                    .foregroundStyle(row.financials.profit >= 0 ? Theme.positive.gradient : Theme.negative.gradient)
                    .annotation(position: row.financials.profit >= 0 ? .trailing : .leading) {
                        Text(money.string(row.financials.profit, compact: true)).font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(ranked.count) * 28)
        }
        .card()
    }

    private func dueCard(report: FleetReport, snapshot: FleetSnapshot) -> some View {
        let items = report.dueItems.prefix(5)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Coming up", subtitle: "Services and paperwork in the next 60 days")
            if items.isEmpty { Text("Nothing due soon.").foregroundStyle(.secondary) }
            ForEach(Array(items)) { item in
                if let vehicle = snapshot.vehicle(id: item.vehicleId) {
                    NavigationLink(value: vehicle) {
                        DueItemRow(item: item, plate: vehicle.plate)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }
}
