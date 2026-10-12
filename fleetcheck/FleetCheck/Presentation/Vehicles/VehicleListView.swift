import SwiftUI

struct VehicleListView: View {
    enum SortOrder: String, CaseIterable, Identifiable {
        case plate = "Plate", profit = "Profit", value = "Value", distance = "Distance"
        var id: String { rawValue }
    }

    @Environment(FleetStore.self) private var store
    @Environment(LiveTrackingStore.self) private var live
    @State private var searchText = ""
    @State private var sortOrder = SortOrder.plate

    var body: some View {
        NavigationStack {
            LoadingStateView(state: store.state, retry: store.reload) {
                List(rows) { report in
                    NavigationLink(value: report.vehicle) {
                        VehicleRow(report: report, status: LiveStatus(vehicle: report.vehicle, position: live.positions[report.vehicle.id]),
                                   money: store.money)
                    }
                }
                .searchable(text: $searchText, prompt: "Plate, make, driver")
                .refreshable { await store.reload() }
            }
            .navigationTitle("Vehicles")
            .navigationDestination(for: Vehicle.self) { VehicleDetailView(vehicleId: $0.id) }
            .toolbar {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
        }
    }

    private var rows: [VehicleReport] {
        let all = store.report?.vehicles ?? []
        let filtered = searchText.isEmpty ? all : all.filter {
            "\($0.vehicle.plate) \($0.vehicle.displayName) \($0.driver?.name ?? "")".localizedCaseInsensitiveContains(searchText)
        }
        return switch sortOrder {
        case .plate: filtered.sorted { $0.vehicle.plate < $1.vehicle.plate }
        case .profit: filtered.sorted { $0.financials.profit > $1.financials.profit }
        case .value: filtered.sorted { ($0.valuation?.currentValue ?? 0) > ($1.valuation?.currentValue ?? 0) }
        case .distance: filtered.sorted { $0.usage.distanceKm > $1.usage.distanceKm }
        }
    }
}

private struct VehicleRow: View {
    let report: VehicleReport
    let status: LiveStatus
    let money: MoneyFormatter

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: report.vehicle.segment == .van ? "box.truck.fill" : "car.fill")
                .font(.title3)
                .foregroundStyle(status.color)
                .frame(width: 40, height: 40)
                .background(status.color.opacity(0.15), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(report.vehicle.plate).font(.headline)
                    StatusBadge(text: status.rawValue, color: status.color)
                }
                Text("\(report.vehicle.displayName) · \(report.driver?.name ?? "Unassigned")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(money.string(report.financials.profit, compact: true))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(report.financials.profit >= 0 ? Theme.positive : Theme.negative)
                Text(report.valuation.map { "worth \(money.string($0.currentValue, compact: true))" } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
