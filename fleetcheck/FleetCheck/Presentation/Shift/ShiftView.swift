import SwiftData
import SwiftUI

/// Home screen: start/end a shift and see today at a glance.
struct ShiftView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(\.money) private var money
    @Query(sort: \Shift.start, order: .reverse) private var shifts: [Shift]
    @Query private var earnings: [Earning]
    @Query private var expenses: [Expense]
    @State private var confirmEnd = false
    @State private var addingExpense = false
    @State private var addingManualShift = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let shift = store.activeShift {
                        activeShiftSection(shift)
                    } else {
                        startButton
                    }
                    todaySection
                    recentShiftsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(store.isOnShift ? "On shift" : "Shift")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("Expense", systemImage: "fuelpump") { addingExpense = true }
                        Button("Past shift", systemImage: "clock.arrow.circlepath") { addingManualShift = true }
                    }
                }
            }
            .sheet(isPresented: $addingExpense) { ExpenseForm() }
            .sheet(isPresented: $addingManualShift) { ManualShiftForm() }
            .navigationDestination(for: Shift.self) { ShiftDetailView(shift: $0) }
        }
    }

    // MARK: - Start / active

    private var startButton: some View {
        Button {
            store.startShift()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 40, weight: .bold))
                Text("Start shift").font(.title2.bold())
                Text("Tracks kilometers and time while you drive").font(.footnote).opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Theme.accent.gradient, in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shift.start")
    }

    @ViewBuilder
    private func activeShiftSection(_ shift: Shift) -> some View {
        if store.gpsStatus == .denied {
            locationDeniedBanner
        }
        RouteMap(route: store.route)
            .frame(height: 240)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            .overlay(alignment: .topLeading) { gpsBadge.padding(10) }

        TimelineView(.periodic(from: shift.start, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(shift.start)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KPITile(title: "Time on shift", value: clock(elapsed), symbol: "clock")
                KPITile(title: "Distance", value: (store.distanceMeters / 1000).kilometers, symbol: "road.lanes")
                KPITile(title: "Driving", value: clock(store.movingSeconds), symbol: "car.side",
                        footnote: elapsed > 60 ? "\((store.movingSeconds / elapsed).percentString) of the shift" : nil)
                KPITile(title: "Waiting", value: clock(max(0, elapsed - store.movingSeconds)), symbol: "hourglass",
                        footnote: "Parked, queues, traffic jams")
            }
        }

        HStack(spacing: 12) {
            Button { addingExpense = true } label: {
                Label("Add expense", systemImage: "fuelpump").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button(role: .destructive) { confirmEnd = true } label: {
                Label("End shift", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .accessibilityIdentifier("shift.end")
        }
        .confirmationDialog("End this shift?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End shift", role: .destructive) { store.endShift() }
        } message: {
            Text("You'll be asked what you earned.")
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }

    private var gpsBadge: some View {
        let (text, color): (String, Color) = switch store.gpsStatus {
        case .tracking: ("GPS on", .green)
        case .waitingForFix, .idle: ("Waiting for GPS…", .orange)
        case .unavailable: ("GPS unavailable", .orange)
        case .denied: ("Location off", .red)
        }
        return Label(text, systemImage: "location.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: .capsule)
            .foregroundStyle(color)
    }

    private var locationDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location access is off", systemImage: "location.slash.fill").font(.headline).foregroundStyle(.red)
            Text("FleetCheck needs your location while you use the app to count kilometers. Your route stays on this iPhone.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.bordered)
        }
        .card()
    }

    // MARK: - Today

    private var todaySection: some View {
        let stats = StatsCalculator().stats(
            in: StatsPeriod.day.interval(containing: .now),
            shifts: shifts.filter { !$0.isActive }.map(\.figures),
            earnings: earnings.map(\.figures), expenses: expenses.map(\.figures))
        return VStack(spacing: 12) {
            SectionHeader(title: "Today", subtitle: store.isOnShift ? "Finished shifts only" : nil)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KPITile(title: "Earned", value: money.string(stats.earnings), symbol: "banknote")
                KPITile(title: "Net after costs", value: money.string(stats.net), symbol: "equal.circle",
                        tint: Theme.color(forNet: stats.net))
                KPITile(title: "Kilometers", value: stats.km.kilometers, symbol: "road.lanes")
                KPITile(title: "Per hour", value: stats.earningsPerHour.map { money.string($0) } ?? "—", symbol: "clock",
                        footnote: stats.hours > 0 ? "over \(Formatters.hours(stats.hours))" : nil)
            }
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentShiftsSection: some View {
        let finished = shifts.filter { !$0.isActive }.prefix(7)
        if !finished.isEmpty {
            VStack(spacing: 0) {
                SectionHeader(title: "Recent shifts").padding(.bottom, 8)
                ForEach(Array(finished)) { shift in
                    NavigationLink(value: shift) {
                        ShiftRow(shift: shift)
                    }
                    .buttonStyle(.plain)
                    if shift.id != finished.last?.id { Divider() }
                }
            }
            .card()
        }
    }
}

struct ShiftRow: View {
    let shift: Shift
    @Environment(\.money) private var money

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.start.formatted(.dateTime.weekday(.wide).day().month())).font(.subheadline.weight(.medium))
                Text("\(shift.start.formatted(date: .omitted, time: .shortened)) · \(Formatters.duration(shift.duration)) · \(shift.distanceKm.kilometers)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(shift.earnings.isEmpty ? "Add earnings" : money.string(shift.earningsTotal))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(shift.earnings.isEmpty ? Theme.accent : .primary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}
