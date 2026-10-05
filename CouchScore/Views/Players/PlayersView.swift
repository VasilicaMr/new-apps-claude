import SwiftUI

struct PlayersView: View {
    @Environment(AppStore.self) private var store
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Add a player or team", text: $newName)
                        .onSubmit {
                            store.addPlayer(named: newName)
                            newName = ""
                        }
                } footer: {
                    Text("Hold on a player to remove them. Past games keep their scores.")
                }

                Section("Leaderboard") {
                    ForEach(rankedPlayers, id: \.player.id) { entry in
                        Button {} label: {
                            HStack(spacing: 24) {
                                Circle()
                                    .fill(PlayerPalette.color(entry.player.colorIndex))
                                    .frame(width: 30, height: 30)
                                Text(entry.player.name)
                                Spacer()
                                Text("\(entry.wins) \(entry.wins == 1 ? "win" : "wins") · \(entry.played) played")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("Remove \(entry.player.name)", role: .destructive) {
                                store.deletePlayer(entry.player)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 80)
            .background(.appBackground)
        }
    }

    private var rankedPlayers: [(player: Player, played: Int, wins: Int)] {
        store.players
            .map { player in
                let stats = store.stats(for: player)
                return (player, stats.played, stats.wins)
            }
            .sorted { ($0.wins, -$0.played) > ($1.wins, -$1.played) }
    }
}
