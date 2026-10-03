import SwiftUI
import SwiftData

struct EditTaskSheet: View {
    let task: UCTask
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: UCTask) {
        self.task = task
        _title      = State(initialValue: task.title)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate    = State(initialValue: task.dueDate
                            ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                }
                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.title   = title
                        task.dueDate = hasDueDate ? dueDate : nil
                        try? context.save()
                        NotificationScheduler.cancel(for: task)
                        if !task.isCompleted { NotificationScheduler.schedule(for: task) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
