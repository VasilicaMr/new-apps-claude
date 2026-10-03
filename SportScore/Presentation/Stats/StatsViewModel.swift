import Foundation

struct PlayerStat: Identifiable {
    let id: UUID
    let player: Player
    let gamesPlayed: Int
    let wins: Int
    var winRate: Double { gamesPlayed > 0 ? Double(wins) / Double(gamesPlayed) : 0 }
    let favoriteSport: SportType?
}

struct SportStat: Identifiable {
    let id: String
    let sport: SportType
    let sportName: String
    let sportIcon: String
    let gamesPlayed: Int
    let completedGames: Int
}

@Observable
@MainActor
final class StatsViewModel {
    var playerStats: [PlayerStat] = []
    var sportStats: [SportStat] = []
    var isLoading: Bool = false

    private let fetchSessions: FetchSessionsUseCase

    init(fetchSessions: FetchSessionsUseCase) {
        self.fetchSessions = fetchSessions
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let sessions = (try? await fetchSessions.execute()) ?? []
        playerStats = computePlayerStats(from: sessions)
        sportStats = computeSportStats(from: sessions)
    }

    private func computePlayerStats(from sessions: [GameSession]) -> [PlayerStat] {
        var allPlayers: [UUID: Player] = [:]
        var gamesPlayed: [UUID: Int] = [:]
        var wins: [UUID: Int] = [:]
        var sportCounts: [UUID: [SportType: Int]] = [:]

        for session in sessions {
            for player in session.players {
                allPlayers[player.id] = player
                gamesPlayed[player.id, default: 0] += 1
                sportCounts[player.id, default: [:]][session.sport, default: 0] += 1
            }
            if let winnerID = session.winnerID {
                wins[winnerID, default: 0] += 1
            }
        }

        return allPlayers.map { id, player in
            let played = gamesPlayed[id] ?? 0
            let won = wins[id] ?? 0
            let favSport = sportCounts[id]?.max(by: { $0.value < $1.value })?.key
            return PlayerStat(id: id, player: player, gamesPlayed: played, wins: won, favoriteSport: favSport)
        }
        .sorted { $0.wins > $1.wins }
    }

    private func computeSportStats(from sessions: [GameSession]) -> [SportStat] {
        let grouped = Dictionary(grouping: sessions, by: { $0.sport })
        return grouped.map { sport, sportSessions in
            SportStat(
                id: sport.rawValue,
                sport: sport,
                sportName: sport.displayName,
                sportIcon: sport.systemImageName,
                gamesPlayed: sportSessions.count,
                completedGames: sportSessions.filter { $0.winnerID != nil }.count
            )
        }
        .sorted { $0.gamesPlayed > $1.gamesPlayed }
    }
}
