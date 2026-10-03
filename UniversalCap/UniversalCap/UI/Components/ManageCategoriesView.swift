import SwiftUI

struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CategoryStore.shared
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.defaults, id: \.self) { cat in
                        Label(cat, systemImage: "tag.fill")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Built-in")
                } footer: {
                    Text("Built-in categories cannot be removed.")
                }

                Section("Custom") {
                    ForEach(store.custom, id: \.self) { cat in
                        Text(cat)
                    }
                    .onDelete { store.remove(at: $0) }

                    HStack {
                        TextField("New category name", text: $newName)
                            .autocorrectionDisabled()
                        Button("Add") {
                            store.add(newName)
                            newName = ""
                        }
                        .fontWeight(.semibold)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
