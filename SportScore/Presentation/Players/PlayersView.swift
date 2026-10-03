import SwiftUI

struct PlayersView: View {
    @State var viewModel: PlayersViewModel
    @State private var showAddPlayer = false
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(viewModel.players) { player in
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Text(player.initials)
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    Text(player.name).font(.body)
                    Spacer()
                }
            }
            .onDelete { indexSet in
                Task { await viewModel.deletePlayers(at: indexSet) }
            }
        }
        .navigationTitle("Players")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "person.badge.plus") {
                    showAddPlayer = true
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .task { await viewModel.load() }
        .alert("New Player", isPresented: $showAddPlayer) {
            TextField("Name", text: $newName)
            Button("Add") {
                Task {
                    await viewModel.addPlayer(name: newName)
                    newName = ""
                }
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
    }
}
