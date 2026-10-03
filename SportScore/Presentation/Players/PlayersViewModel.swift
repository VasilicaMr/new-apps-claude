import Foundation

@Observable
@MainActor
final class PlayersViewModel {
    var players: [Player] = []
    var isLoading: Bool = false

    private let fetchPlayers: FetchPlayersUseCase
    private let createPlayer: CreatePlayerUseCase
    private let deletePlayer: DeletePlayerUseCase

    init(fetchPlayers: FetchPlayersUseCase, createPlayer: CreatePlayerUseCase, deletePlayer: DeletePlayerUseCase) {
        self.fetchPlayers = fetchPlayers
        self.createPlayer = createPlayer
        self.deletePlayer = deletePlayer
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        players = (try? await fetchPlayers.execute()) ?? []
    }

    func addPlayer(name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let player = try? await createPlayer.execute(name: name) {
            players.append(player)
        }
    }

    func deletePlayers(at offsets: IndexSet) async {
        for index in offsets {
            try? await deletePlayer.execute(id: players[index].id)
        }
        players.remove(atOffsets: offsets)
    }
}
