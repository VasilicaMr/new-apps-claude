import Charts
import SwiftUI

struct VehicleDetailView: View {
    let vehicleId: String
    @Environment(FleetStore.self) private var store
    @Environment(LiveTrackingStore.self) private var live

    var body: some View {
        Group {
            if let report = store.report(for: vehicleId), let snapshot = store.snapshot {
                content(report: report, snapshot: snapshot)
            } else {
                ContentUnavailableView("Vehicle not found", systemImage: "car")
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func content(report: VehicleReport, snapshot: FleetSnapshot) -> some View {
        @Bindable var store = store
        let money = store.money
        let vehicle = report.vehicle
        return ScrollView {
            VStack(spacing: 16) {
                header(report)
                LiveSection(vehicle: vehicle, telemetry: snapshot.telemetry(for: vehicle.id), position: live.positions[vehicle.id])

                let vehicleInsights = store.insights(for: vehicle.id)
                if !vehicleInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Recommendations")
                        ForEach(vehicleInsights) { InsightRow(insight: $0, money: money) }
                    }
                    .card()
                }

                PeriodPicker(period: $store.period)
                FinancialsSection(report: report, money: money, period: store.period)
                if let valuation = report.valuation {
                    ValuationSection(valuation: valuation, odometerKm: vehicle.odometerKm, money: money)
                }
                UsageSection(report: report)
                MaintenanceSection(report: report, records: snapshot.maintenance(for: vehicle.id), money: money)
                TripsSection(trips: Array(snapshot.trips(for: vehicle.id).prefix(8)), money: money)
                detailsSection(vehicle)
            }
            .padding()
        }
        .navigationTitle(vehicle.plate)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ report: VehicleReport) -> some View {
        let status = LiveStatus(vehicle: report.vehicle, position: live.positions[report.vehicle.id])
        return HStack(spacing: 14) {
            Image(systemName: report.vehicle.segment == .van ? "box.truck.fill" : "car.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(status.color.gradient, in: .rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(report.vehicle.displayName).font(.title3.weight(.semibold))
                Text("\(String(report.vehicle.year)) · \(report.vehicle.fuelType.rawValue.capitalized) · \(report.vehicle.odometerKm.kilometers)")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    StatusBadge(text: status.rawValue, color: status.color)
                    if let driver = report.driver {
                        Label(driver.name, systemImage: "person.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .card()
    }

    private func detailsSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Vehicle details")
            LabeledContent("VIN", value: vehicle.vin).font(.caption.monospaced())
            LabeledContent("Color", value: vehicle.color)
            LabeledContent("Purchased", value: vehicle.purchaseDate.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Purchase price", value: store.money.string(vehicle.purchasePrice))
            LabeledContent("Service interval", value: vehicle.serviceIntervalKm.kilometers)
            if vehicle.monthlyFinancingCost > 0 {
                LabeledContent("Leasing", value: "\(store.money.string(vehicle.monthlyFinancingCost))/month")
            }
        }
        .font(.subheadline)
        .card()
    }
}

private struct LiveSection: View {
    let vehicle: Vehicle
    let telemetry: TelemetrySnapshot?
    let position: VehiclePosition?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Right now", subtitle: telemetry.map { "Telematics updated \($0.timestamp.formatted(.relative(presentation: .named)))" })
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    gauge("Speed", position.map { "\(Int($0.speedKmh)) km/h" } ?? "\(Int(telemetry?.speedKmh ?? 0)) km/h", "speedometer")
                    gauge(vehicle.fuelType == .electric ? "Battery" : "Fuel", "\(Int(telemetry?.fuelLevelPercent ?? 0))%", vehicle.fuelType == .electric ? "battery.75percent" : "fuelpump",
                          warn: (telemetry?.fuelLevelPercent ?? 100) < 15)
                }
                GridRow {
                    gauge("12V battery", String(format: "%.1f V", telemetry?.batteryVoltage ?? 0), "minus.plus.batteryblock",
                          warn: (telemetry?.batteryVoltage ?? 13) < 12)
                    gauge("Engine temp", vehicle.fuelType == .electric ? "—" : "\(Int(telemetry?.engineTemperatureC ?? 0)) °C", "thermometer.medium",
                          warn: (telemetry?.engineTemperatureC ?? 0) > 100)
                }
            }
            if let codes = telemetry?.diagnosticCodes, !codes.isEmpty {
                Label("Fault codes: \(codes.joined(separator: ", "))", systemImage: "engine.combustion.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
            }
        }
        .card()
    }

    private func gauge(_ title: String, _ value: String, _ symbol: String, warn: Bool = false) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(warn ? .red : Theme.accent).frame(width: 22)
            VStack(alignment: .leading) {
                Text(value).font(.headline.monospacedDigit()).foregroundStyle(warn ? .red : .primary)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FinancialsSection: View {
    let report: VehicleReport
    let money: MoneyFormatter
    let period: AnalysisPeriod

    var body: some View {
        let f = report.financials
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Money", subtitle: "Last \(period.rawValue) days")
            HStack {
                metric("Revenue", money.string(f.revenue), .primary)
                metric("Costs", money.string(f.totalCost), .primary)
                metric("Profit", money.string(f.profit), f.profit >= 0 ? Theme.positive : Theme.negative)
            }
            Divider()
            row("Fuel / energy", f.energyCost)
            row("Maintenance & repairs", f.maintenanceCost)
            ForEach(f.expenses.sorted { $0.value > $1.value }, id: \.key) { row($0.key.label, $0.value) }
            row("Depreciation (value lost)", f.depreciation)
            Divider()
            HStack {
                metric("Revenue / km", money.string(f.revenue / max(report.usage.distanceKm, 1)), .primary)
                metric("Cost / km", money.string(report.costPerKm), .primary)
                metric("Profit / km", money.string(report.profitPerKm), report.profitPerKm >= 0 ? Theme.positive : Theme.negative)
            }
            if report.monthly.count > 1 {
                Chart(report.monthly) { month in
                    BarMark(x: .value("Month", month.month, unit: .month), y: .value("Profit", month.financials.profit))
                        .foregroundStyle(month.financials.profit >= 0 ? Theme.positive : Theme.negative)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Double.self) { Text(money.string(v, compact: true)) } }
                    }
                }
                .frame(height: 140)
            }
        }
        .card()
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(value).font(.headline).foregroundStyle(color).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ title: String, _ amount: Double) -> some View {
        LabeledContent(title, value: money.string(amount)).font(.subheadline)
    }
}

private struct ValuationSection: View {
    let valuation: VehicleValuation
    let odometerKm: Double
    let money: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Market value", subtitle: "Estimated from age and mileage, projected at the current km/year pace")
            HStack(alignment: .firstTextBaseline) {
                Text(money.string(valuation.currentValue)).font(.title2.weight(.bold))
                Text("\(valuation.retainedShare.percentString) of \(money.string(valuation.purchasePrice))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(mileageNote).font(.caption).foregroundStyle(valuation.mileageFactor < 1 ? .orange : .green)
            Chart {
                ForEach(valuation.curve) { point in
                    AreaMark(x: .value("Odometer", point.odometerKm), y: .value("Value", point.value))
                        .foregroundStyle(Theme.accent.opacity(0.12))
                    LineMark(x: .value("Odometer", point.odometerKm), y: .value("Value", point.value))
                        .foregroundStyle(Theme.accent)
                }
                RuleMark(x: .value("Now", odometerKm))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) { Text("Today").font(.caption2) }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let km = value.as(Double.self) { Text("\(Int(km / 1000))k km") } }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let v = value.as(Double.self) { Text(money.string(v, compact: true)) } }
                }
            }
            .frame(height: 180)
        }
        .card()
    }

    private var mileageNote: String {
        let delta = valuation.mileageFactor - 1
        if abs(delta) < 0.02 { return "Mileage is about average for its age." }
        return delta < 0
            ? "High mileage lowers its value by \((-delta).percentString)."
            : "Low mileage adds \(delta.percentString) to its value."
    }
}

private struct UsageSection: View {
    let report: VehicleReport

    var body: some View {
        let usage = report.usage
        let unit = report.vehicle.fuelType.energyUnit
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Usage & driving")
            LabeledContent("Distance", value: usage.distanceKm.kilometers)
            LabeledContent("Days worked", value: "\(usage.activeDays) of \(usage.totalDays) (\(usage.utilization.percentString))")
            LabeledContent("Jobs completed", value: "\(usage.jobs)")
            LabeledContent("Consumption", value: String(format: "%.1f %@/100 km (baseline %.1f)", usage.consumptionPer100Km, unit, report.vehicle.baselineConsumption))
            LabeledContent("Idling", value: "\(Int(usage.idleMinutes / 60)) h (\(usage.idleShare.percentString) of engine time)")
            HStack {
                Text("Driving score")
                Spacer()
                Gauge(value: usage.drivingScore, in: 0...100) { EmptyView() } currentValueLabel: {
                    Text("\(Int(usage.drivingScore))")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(usage.drivingScore > 80 ? .green : usage.drivingScore > 60 ? .orange : .red)
                .scaleEffect(0.8)
            }
        }
        .font(.subheadline)
        .card()
    }
}

private struct MaintenanceSection: View {
    let report: VehicleReport
    let records: [MaintenanceRecord]
    let money: MoneyFormatter
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Maintenance & repairs",
                          subtitle: "\(money.string(report.maintenanceLast12Months)) in the last 12 months · \(records.count) records total")
            ForEach(report.dueItems) { DueItemRow(item: $0, plate: nil) }
            if !report.dueItems.isEmpty { Divider() }
            ForEach(showAll ? records : Array(records.prefix(5))) { record in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: record.category.symbol)
                        .foregroundStyle(record.isUnplanned ? .orange : Theme.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.description).font(.subheadline)
                        Text("\(record.date.formatted(date: .abbreviated, time: .omitted)) · \(record.odometerKm.kilometers) · \(record.garage)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(money.string(record.totalCost)).font(.subheadline.weight(.semibold))
                        if record.isUnplanned { Text("unplanned").font(.caption2).foregroundStyle(.orange) }
                    }
                }
            }
            if records.count > 5 {
                Button(showAll ? "Show less" : "Show all \(records.count)") { withAnimation { showAll.toggle() } }
                    .font(.subheadline)
            }
        }
        .card()
    }
}

private struct TripsSection: View {
    let trips: [Trip]
    let money: MoneyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent trips")
            if trips.isEmpty { Text("No trips in the last week.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(trips) { trip in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trip.startAddress) → \(trip.endAddress)").font(.subheadline).lineLimit(1)
                        Text("\(trip.startTime.formatted(date: .abbreviated, time: .shortened)) · \(trip.distanceKm.kilometers) · max \(Int(trip.maxSpeedKmh)) km/h")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(money.string(trip.revenue)).font(.subheadline.weight(.semibold))
                }
            }
        }
        .card()
    }
}
