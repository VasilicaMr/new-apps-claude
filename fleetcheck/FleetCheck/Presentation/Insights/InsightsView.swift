import Charts
import SwiftUI

struct InsightsView: View {
    @Environment(FleetStore.self) private var store
    @State private var severityFilter: Severity?

    var body: some View {
        NavigationStack {
            LoadingStateView(state: store.state, retry: store.reload) {
                if let report = store.report { content(report) }
            }
            .navigationTitle("Insights")
            .navigationDestination(for: String.self) { VehicleDetailView(vehicleId: $0) }
        }
    }

    private func content(_ report: FleetReport) -> some View {
        @Bindable var store = store
        let money = store.money
        let filtered = store.insights.filter { severityFilter == nil || $0.severity == severityFilter }
        let atStake = store.insights.compactMap(\.monthlyImpact).filter { $0 > 0 }.reduce(0, +)
        return List {
            Section {
                PeriodPicker(period: $store.period)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Money at stake").font(.caption).foregroundStyle(.secondary)
                    Text("\(money.string(atStake))/month").font(.title2.weight(.bold)).foregroundStyle(Theme.negative)
                    Text("Estimated savings if every recommendation below is acted on.").font(.caption).foregroundStyle(.secondary)
                }
                Picker("Severity", selection: $severityFilter) {
                    Text("All (\(store.insights.count))").tag(Severity?.none)
                    ForEach(Severity.allCases.reversed(), id: \.self) { severity in
                        Text("\(severity.rawValue.capitalized) (\(store.insights.filter { $0.severity == severity }.count))").tag(Optional(severity))
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Recommendations") {
                ForEach(filtered) { insight in
                    if let vehicleId = insight.vehicleId {
                        NavigationLink(value: vehicleId) { InsightRow(insight: insight, money: money) }
                    } else {
                        InsightRow(insight: insight, money: money)
                    }
                }
            }

            Section("Where the money goes") {
                Chart(report.costBreakdown, id: \.label) { row in
                    SectorMark(angle: .value("Amount", row.amount), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(by: .value("Category", row.label))
                }
                .frame(height: 220)
                .padding(.vertical, 8)
                ForEach(report.costBreakdown, id: \.label) { row in
                    LabeledContent(row.label, value: money.string(row.amount))
                }
            }

            Section("Cost per km by vehicle") {
                Chart(report.vehicles.sorted { $0.costPerKm > $1.costPerKm }) { row in
                    BarMark(x: .value("Cost per km", row.costPerKm), y: .value("Vehicle", row.vehicle.plate))
                        .foregroundStyle(Theme.accent.gradient)
                    BarMark(x: .value("Revenue per km", row.financials.revenue / max(row.usage.distanceKm, 1)), y: .value("Vehicle", row.vehicle.plate))
                        .foregroundStyle(.clear)
                        .annotation(position: .overlay, alignment: .trailing) {
                            Rectangle().fill(.primary).frame(width: 2, height: 14)
                        }
                }
                .frame(height: CGFloat(report.vehicles.count) * 30)
                Text("Bars show cost per km; the black tick shows revenue per km. Bars crossing the tick lose money on every km.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Driver ranking") {
                ForEach(report.vehicles.sorted { $0.usage.drivingScore > $1.usage.drivingScore }) { row in
                    HStack {
                        Text(row.driver?.initials ?? "?")
                            .font(.caption.weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(Theme.accent.opacity(0.15), in: .circle)
                        VStack(alignment: .leading) {
                            Text(row.driver?.name ?? "Unassigned").font(.subheadline)
                            Text("\(row.vehicle.plate) · \(String(format: "%.1f", row.usage.harshEventsPer100Km)) events/100 km")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(row.usage.drivingScore))")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(row.usage.drivingScore > 80 ? .green : row.usage.drivingScore > 60 ? .orange : .red)
                    }
                }
            }
        }
    }
}
