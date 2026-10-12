import SwiftData
import SwiftUI

/// Start button, or the running shift's map, timers and End button. Lives at the top of Home.
struct ShiftCard: View {
    @Environment(ShiftStore.self) private var store
    @Binding var addingExpense: Bool
    @State private var confirmEnd = false

    var body: some View {
        if let shift = store.activeShift {
            activeShiftSection(shift)
        } else {
            startButton
        }
    }

    // MARK: - Start / active

    private var startButton: some View {
        Button {
            store.startShift()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .font(.title2.weight(.bold))
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.2), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start shift").font(.title3.bold())
                    Text("Kilometers and time are tracked automatically").font(.footnote).opacity(0.85)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(Theme.accent.gradient, in: .rect(cornerRadius: 22))
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
