import SwiftUI
import SwiftData

struct EditThoughtSheet: View {
    let thought: Thought
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var content: String

    init(thought: Thought) {
        self.thought = thought
        _content = State(initialValue: thought.content)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Edit Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        thought.content = content
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
