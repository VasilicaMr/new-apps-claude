import Foundation

@Observable
@MainActor
final class SessionSetupViewModel {
    let sport: SportType
    /// Rules snapshot for home/custom games, stored with the session.
    let configJSON: Data?
    var selectedVariant: String
    var selectedPlayers: [Player] = []
    var allPlayers: [Player] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let startSession: StartSessionUseCase
    private let fetchPlayers: FetchPlayersUseCase
    private let createPlayer: CreatePlayerUseCase

    init(sport: SportType, configJSON: Data? = nil, startSession: StartSessionUseCase, fetchPlayers: FetchPlayersUseCase, createPlayer: CreatePlayerUseCase) {
        self.sport = sport
        self.configJSON = configJSON
        self.startSession = startSession
        self.fetchPlayers = fetchPlayers
        self.createPlayer = createPlayer
        self.selectedVariant = sport.defaultVariants.first ?? "Standard"
    }

    func loadPlayers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            allPlayers = try await fetchPlayers.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPlayer(name: String) async -> Player? {
        do {
            let player = try await createPlayer.execute(name: name)
            allPlayers.append(player)
            return player
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func togglePlayer(_ player: Player) {
        if selectedPlayers.contains(where: { $0.id == player.id }) {
            selectedPlayers.removeAll { $0.id == player.id }
        } else {
            selectedPlayers.append(player)
        }
    }

    func startGame() async -> UUID? {
        guard !selectedPlayers.isEmpty else {
            errorMessage = "Select at least one player"
            return nil
        }
        do {
            let session = try await startSession.execute(
                sport: sport,
                variant: configJSON == nil ? selectedVariant : nil,
                players: selectedPlayers,
                configJSON: configJSON
            )
            return session.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
