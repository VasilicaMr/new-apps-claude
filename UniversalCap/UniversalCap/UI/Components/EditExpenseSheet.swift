import SwiftUI
import SwiftData

struct EditExpenseSheet: View {
    let expense: Expense
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var currency: String
    @State private var category: String
    @State private var note: String

    @State private var categoryStore = CategoryStore.shared
    @State private var store = StoreKitManager.shared
    @State private var showManageCategories = false

    init(expense: Expense) {
        self.expense = expense
        _amount   = State(initialValue: expense.amount)
        _currency = State(initialValue: expense.currency)
        _category = State(initialValue: expense.category)
        _note     = State(initialValue: expense.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("EUR", text: $currency)
                            .frame(width: 52)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        Divider()
                        TextField("0.00", value: $amount,
                                  format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categoryStore.all, id: \.self) { Text($0) }
                    }
                    if store.isPro {
                        Button {
                            showManageCategories = true
                        } label: {
                            Label("Manage categories", systemImage: "tag")
                                .font(.subheadline)
                        }
                    }
                }
                Section("Note") {
                    TextField("Optional note", text: $note)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        expense.amount   = amount
                        expense.currency = currency.uppercased()
                        expense.category = category
                        expense.note     = note
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showManageCategories) {
                ManageCategoriesView()
            }
        }
    }
}
