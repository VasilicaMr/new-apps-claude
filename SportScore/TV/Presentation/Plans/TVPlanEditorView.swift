import SwiftUI

struct TVPlanEditorView: View {
    let store: GamePlansStore
    let gameTitles: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var plan: GamePlan

    private static let symbols = [
        "flame.fill", "calendar", "house.fill", "person.3.fill", "heart.fill",
        "star.fill", "trophy.fill", "dice.fill", "suit.spade.fill", "gamecontroller.fill",
    ]

    init(plan: GamePlan, store: GamePlansStore, gameTitles: [String]) {
        self.store = store
        self.gameTitles = gameTitles
        _plan = State(initialValue: plan)
    }

    private var trimmedName: String { plan.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Plan name, e.g. Family Game Night", text: $plan.name)
                    // Not the default segmented style: ~90 games or 10 icons don't fit in one row.
                    Picker(selection: $plan.symbol) {
                        ForEach(Self.symbols, id: \.self) { Image(systemName: $0).tag($0) }
                    } label: {
                        Label("Icon", systemImage: plan.symbol)
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Game", selection: $plan.gameTitle) {
                        Text("Any game").tag(String?.none)
                        ForEach(gameTitles, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Goal", selection: $plan.timesPerWeek) {
                        ForEach(1...7, id: \.self) { Text($0 == 7 ? "Every day" : "\($0)× a week").tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Button {
                        var saved = plan
                        saved.name = trimmedName
                        store.save(saved)
                        dismiss()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .disabled(trimmedName.isEmpty)

                    if store.contains(plan) {
                        Button(role: .destructive) {
                            store.delete(plan)
                            dismiss()
                        } label: {
                            Label("Delete Plan", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(store.contains(plan) ? "Edit Plan" : "New Plan")
        }
    }
}
