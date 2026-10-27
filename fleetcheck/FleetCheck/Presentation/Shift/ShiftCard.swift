import SwiftData
import SwiftUI

/// Start button, or the running shift's clock, totals and End button. Lives at the top of Home.
struct ShiftCard: View {
    @Environment(ShiftStore.self) private var store
    @Binding var addingExpense: Bool
    @State private var confirmEnd = false
    @State private var addingTrip = false

    var body: some View {
        if let shift = store.activeShift {
            activeShiftSection(shift)
        } else {
            startButton
        }
    }

    // MARK: - Start / active

    /// Secondary to uploading earnings: shifts only add the hours, for earnings per hour.
    private var startButton: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: "steeringwheel", tint: Theme.blue, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Track your hours")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Start a shift when you go online to see what you make per hour. No GPS.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                store.startShift()
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(CapsuleButtonStyle(compact: true))
            .accessibilityIdentifier("shift.start")
        }
        .card()
    }

    @ViewBuilder
    private func activeShiftSection(_ shift: Shift) -> some View {
        TimelineView(.periodic(from: shift.start, by: 1)) { context in
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KPITile(title: "Time on shift", value: clock(context.date.timeIntervalSince(shift.start)), symbol: "clock")
                KPITile(title: "Distance", value: shift.distanceKm.kilometers, symbol: "road.lanes",
                        footnote: String(localized: "From your trip screenshots"))
            }
        }

        Button { addingTrip = true } label: {
            Label("Add trip screenshot", systemImage: "text.viewfinder").frame(maxWidth: .infinity)
        }
        .buttonStyle(CapsuleButtonStyle())
        .accessibilityIdentifier("shift.addTrip")
        .sheet(isPresented: $addingTrip) { EarningForm(shift: shift, scanScreenshot: true) }

        HStack(spacing: 12) {
            Button { addingExpense = true } label: {
                Label("Add expense", systemImage: "fuelpump").frame(maxWidth: .infinity)
            }
            .buttonStyle(CapsuleButtonStyle(filled: false))
            Button(role: .destructive) { confirmEnd = true } label: {
                Label("End shift", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(CapsuleButtonStyle(tint: Theme.negative))
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
}

struct ShiftRow: View {
    let shift: Shift
    @Environment(\.money) private var money

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.start.formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(verbatim: "\(shift.start.formatted(date: .omitted, time: .shortened)) · \(Formatters.duration(shift.duration)) · \(shift.distanceKm.kilometers)")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if shift.earnings.isEmpty {
                Chip(text: "Add earnings", tint: Theme.warning)
            } else {
                Text(money.string(shift.earningsTotal))
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.ink.opacity(0.3))
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
