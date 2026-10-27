import SwiftData
import SwiftUI

struct ShiftDetailView: View {
    @Bindable var shift: Shift
    @Environment(\.money) private var money
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var addingEarning = false
    @State private var editingEarning: Earning?
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Started", value: shift.start.formatted(date: .abbreviated, time: .shortened))
                if let end = shift.end {
                    LabeledContent("Ended", value: end.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Time on shift", value: Formatters.duration(shift.duration))
                LabeledContent("Kilometers") {
                    TextField("km", value: Binding(get: { shift.distanceKm }, set: { shift.distanceMeters = max(0, $0) * 1000 }),
                              format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Summary")
            } footer: {
                Text("Added up from the trips you read from Uber or Bolt screenshots. You can correct it here.")
            }

            Section {
                ForEach(shift.earnings.sorted { $0.total > $1.total }) { earning in
                    Button { editingEarning = earning } label: {
                        EarningRow(earning: earning)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let sorted = shift.earnings.sorted { $0.total > $1.total }
                    for earning in offsets.map({ sorted[$0] }) {
                        context.addKilometers(-earning.distanceKm, to: shift)
                        context.delete(earning)
                    }
                }
                Button("Add earnings", systemImage: "plus.circle.fill") { addingEarning = true }
            } header: {
                Text("Earnings")
            } footer: {
                if shift.earningsTotal > 0 {
                    let hours = shift.duration / 3600
                    Text("\(money.string(shift.earningsTotal)) total · \(money.string(shift.earningsTotal / max(hours, 0.1))) per hour · \(money.string(shift.earningsTotal / max(shift.distanceKm, 0.1), decimals: true)) per km")
                }
            }

            Section("Note") {
                TextField("e.g. airport runs, rain, concert", text: $shift.note, axis: .vertical)
            }

            Section {
                Button("Delete shift", role: .destructive) { confirmDelete = true }
            }
        }
        .fleetBackground()
        .navigationTitle(shift.start.formatted(.dateTime.weekday(.wide).day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingEarning) { EarningForm(shift: shift) }
        .sheet(item: $editingEarning) { EarningForm(shift: shift, editing: $0) }
        .confirmationDialog("Delete this shift?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete shift and its earnings", role: .destructive) {
                shift.earnings.forEach(context.delete)
                context.delete(shift)
                dismiss()
            }
        }
    }
}

struct EarningRow: View {
    let earning: Earning
    @Environment(\.money) private var money

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: "banknote", tint: Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(earning.platform.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text(money.string(earning.total))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
        }
        .contentShape(.rect)
    }

    private var detail: String {
        var parts = [earning.date.formatted(date: .abbreviated, time: .omitted)]
        if !earning.destination.isEmpty { parts.append(String(localized: "to \(earning.destination)")) }
        if earning.trips > 1 { parts.append(String(localized: "\(earning.trips) trips")) }
        if earning.distanceKm > 0 { parts.append(earning.distanceKm.kilometers) }
        if earning.tips > 0 { parts.append(String(localized: "tips \(money.string(earning.tips))")) }
        if earning.bonus > 0 { parts.append(String(localized: "bonus \(money.string(earning.bonus))")) }
        if earning.cashCollected > 0 { parts.append(String(localized: "cash \(money.string(earning.cashCollected))")) }
        return parts.joined(separator: " · ")
    }
}

/// For shifts the driver forgot to track.
struct ManualShiftForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.money) private var money
    @State private var start = Calendar.current.date(byAdding: .hour, value: -8, to: .now) ?? .now
    @State private var end = Date.now
    @State private var km = 0.0
    @State private var addToOdometer = true
    @State private var platform = Platform.uber
    @State private var fares = 0.0
    @State private var tips = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Started", selection: $start)
                    DatePicker("Ended", selection: $end, in: start...)
                    AmountField(title: "Kilometers", value: $km)
                    Toggle("Add to car's odometer", isOn: $addToOdometer)
                } footer: {
                    Text("Check the trip counter on your dashboard or the distance in the Uber app.")
                }
                Section {
                    Picker("App", selection: $platform) {
                        ForEach(Platform.allCases) { Text($0.title).tag($0) }
                    }
                    AmountField(title: "Fares", value: $fares, currencyCode: money.currencyCode)
                    AmountField(title: "Tips", value: $tips, currencyCode: money.currencyCode)
                } header: {
                    Text("Earnings")
                } footer: {
                    Text("Worked for more than one app? Add the others from the shift page afterwards.")
                }
            }
            .fleetBackground()
            .navigationTitle("Past shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(end <= start)
                }
            }
        }
    }

    private func save() {
        let shift = Shift(start: start, end: end, distanceMeters: km * 1000, isManual: true)
        context.insert(shift)
        if fares + tips > 0 {
            context.insert(Earning(date: start, platform: platform, fares: fares, tips: tips, shift: shift))
        }
        if addToOdometer {
            let car = context.car()
            car.odometerKm += km
            car.odometerUpdatedAt = .now
        }
        try? context.save()
        dismiss()
    }
}
