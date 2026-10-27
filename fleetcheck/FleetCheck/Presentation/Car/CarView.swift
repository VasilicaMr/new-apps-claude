import SwiftData
import SwiftUI

/// The car and its paperwork / maintenance reminders.
struct CarView: View {
    @Environment(\.modelContext) private var context
    @Query private var cars: [Car]
    @Query private var reminders: [Reminder]
    @State private var addingReminder = false
    @State private var editingReminder: Reminder?
    @State private var editingCar = false

    private let planner = ReminderPlanner()

    var body: some View {
        let car = cars.first
        let odometer = car?.odometerKm ?? 0
        let sorted = reminders
            .map { ($0, planner.status(of: $0.rule, today: .now, odometerKm: odometer)) }
            .sorted { lhs, rhs in
                if lhs.1.urgency != rhs.1.urgency { return lhs.1.urgency > rhs.1.urgency }
                return (lhs.1.daysLeft ?? Int.max) < (rhs.1.daysLeft ?? Int.max)
            }

        NavigationStack {
            List {
                Section {
                    Button { editingCar = true } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 28, weight: .bold))
                                .frame(width: 64, height: 64)
                                .background(.white.opacity(0.18), in: .rect(cornerRadius: 18, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(car.flatMap { $0.name.isEmpty ? nil : $0.name } ?? String(localized: "Your car"))
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                if let plate = car?.plate, !plate.isEmpty {
                                    Text(plate)
                                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.22), in: .rect(cornerRadius: 6))
                                }
                                Text("Odometer \(odometer.kilometers)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .opacity(0.88)
                            }
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gradientCard(Theme.carGradient, cornerRadius: 26)
                    }
                    .buttonStyle(PressableStyle())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } footer: {
                    Text("Kilometers from tracked shifts and odometer readings on fuel receipts are added automatically.")
                }

                Section {
                    ForEach(sorted, id: \.0.id) { reminder, status in
                        Button { editingReminder = reminder } label: {
                            ReminderRow(reminder: reminder, status: status)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            if reminder.repeatMonths != nil || reminder.repeatKm != nil {
                                Button("Done", systemImage: "checkmark") { markDone(reminder, odometer: odometer) }
                                    .tint(Theme.positive)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(reminder)
                                try? context.save()
                                context.rescheduleReminderNotifications()
                            }
                        }
                    }
                    Button("Add reminder", systemImage: "plus.circle.fill") { addingReminder = true }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("You get a notification 30, 7 and 1 days before each date. Swipe right to mark a repeating item as done.")
                }
            }
            .fleetBackground()
            .navigationTitle("Car")
            .sheet(isPresented: $addingReminder) { ReminderForm(odometer: odometer) }
            .sheet(item: $editingReminder) { ReminderForm(odometer: odometer, editing: $0) }
            .sheet(isPresented: $editingCar) { CarForm(car: context.car()) }
            .overlay {
                if reminders.isEmpty {
                    ContentUnavailableView {
                        Label("No reminders yet", systemImage: "bell.badge")
                    } description: {
                        Text("Add the expiry dates for your inspection (ITP), insurance (RCA) and road vignette so you never drive with expired papers.")
                    } actions: {
                        Button("Add reminder") { addingReminder = true }.buttonStyle(CapsuleButtonStyle())
                    }
                    .padding(.top, 200)
                }
            }
        }
    }

    private func markDone(_ reminder: Reminder, odometer: Double) {
        reminder.rule = planner.nextRule(after: reminder.rule, doneDate: .now, odometerKm: odometer)
        try? context.save()
        context.rescheduleReminderNotifications()
    }
}

struct CarForm: View {
    @Bindable var car: Car
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Make and model", text: $car.name)
                TextField("Plate number", text: $car.plate)
                    .textInputAutocapitalization(.characters)
                LabeledContent("Odometer (km)") {
                    TextField("km", value: $car.odometerKm, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .fleetBackground()
            .navigationTitle("Car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        car.odometerUpdatedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReminderForm: View {
    let odometer: Double
    var editing: Reminder?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ReminderKind
    @State private var title: String
    @State private var hasDate: Bool
    @State private var dueDate: Date
    @State private var hasKm: Bool
    @State private var dueKm: Double
    @State private var repeatMonths: Int
    @State private var repeatKm: Double
    @State private var note: String

    init(odometer: Double, editing: Reminder? = nil) {
        self.odometer = odometer
        self.editing = editing
        let kind = editing?.kind ?? .inspection
        _kind = State(initialValue: kind)
        _title = State(initialValue: editing?.title ?? kind.title)
        _hasDate = State(initialValue: editing.map { $0.dueDate != nil } ?? !kind.usesKilometers)
        _dueDate = State(initialValue: editing?.dueDate ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
        _hasKm = State(initialValue: editing.map { $0.dueKm != nil } ?? kind.usesKilometers)
        _dueKm = State(initialValue: editing?.dueKm ?? (odometer + (kind.defaultRepeatKm ?? 10_000)).rounded())
        _repeatMonths = State(initialValue: editing?.repeatMonths ?? kind.defaultRepeatMonths ?? 0)
        _repeatKm = State(initialValue: editing?.repeatKm ?? kind.defaultRepeatKm ?? 0)
        _note = State(initialValue: editing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ReminderKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    TextField("Title", text: $title)
                }
                Section {
                    Toggle("Due on a date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Expires / due", selection: $dueDate, displayedComponents: .date)
                        Picker("Repeats every", selection: $repeatMonths) {
                            Text("Never").tag(0)
                            ForEach([1, 3, 6, 12, 24], id: \.self) { Text("\($0) months").tag($0) }
                        }
                    }
                }
                Section {
                    Toggle("Due at a mileage", isOn: $hasKm)
                    if hasKm {
                        AmountField(title: "Due at (km)", value: $dueKm)
                        AmountField(title: "Repeats every (km)", value: $repeatKm)
                    }
                } footer: {
                    Text("Odometer now: \(odometer.kilometers).")
                }
                Section {
                    TextField("Note (insurer, policy number…)", text: $note, axis: .vertical)
                }
            }
            .fleetBackground()
            .navigationTitle(editing == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!hasDate && !hasKm)
                }
            }
            .onChange(of: kind) { old, new in
                guard editing == nil else { return }
                if title == old.title { title = new.title }
                hasDate = !new.usesKilometers
                hasKm = new.usesKilometers
                repeatMonths = new.defaultRepeatMonths ?? 0
                repeatKm = new.defaultRepeatKm ?? 0
                if let km = new.defaultRepeatKm { dueKm = (odometer + km).rounded() }
            }
        }
    }

    private func save() {
        let rule = DueRule(dueDate: hasDate ? dueDate : nil, dueKm: hasKm ? dueKm : nil,
                           repeatMonths: hasDate && repeatMonths > 0 ? repeatMonths : nil,
                           repeatKm: hasKm && repeatKm > 0 ? repeatKm : nil)
        let reminder = editing ?? Reminder(kind: kind)
        reminder.kind = kind
        reminder.title = title.isEmpty ? kind.title : title
        reminder.rule = rule
        reminder.note = note
        if editing == nil { context.insert(reminder) }
        try? context.save()
        Task {
            _ = await ReminderNotifier.requestPermission()
            context.rescheduleReminderNotifications()
        }
        dismiss()
    }
}
