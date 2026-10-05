import SwiftUI

struct TVPlayersView: View {
    @State var viewModel: PlayersViewModel
    @State private var showAddPlayer = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                Button {
                    showAddPlayer = true
                } label: {
                    Label("Add player", systemImage: "person.badge.plus")
                }
            }

            Section {
                ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, player in
                    Button {} label: {
                        TVPlayerRow(player: player, showsSelection: false)
                    }
                    .contextMenu {
                        Button("Delete \(player.name)", role: .destructive) {
                            Task { await viewModel.deletePlayers(at: IndexSet(integer: index)) }
                        }
                    }
                }
            } footer: {
                if !viewModel.players.isEmpty {
                    Text("Hold on a player to delete them.")
                }
            }
        }
        .navigationTitle("Players")
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
