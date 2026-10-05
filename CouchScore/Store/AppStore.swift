import Foundation
import Observation

/// Single source of truth for players, custom games and matches.
///
/// tvOS only guarantees ~500 KB of persistent local storage (UserDefaults); everything else is purgeable.
/// So state is kept as compact JSON in UserDefaults, finished matches drop their undo log,
/// and history is capped at `maxStoredMatches`.
@MainActor
@Observable
final class AppStore {
    private(set) var players: [Player] = []
    private(set) var customGames: [GameDefinition] = []
    /// Newest first. At most one match is unfinished at a time.
    private(set) var matches: [Match] = []

    /// The match shown full screen on the scoreboard.
    var presentedMatchID: UUID?

    private let defaults: UserDefaults
    private static let storageKey = "couchScore.state.v1"
    private static let maxStoredMatches = 200

    private struct PersistedState: Codable {
        var players: [Player]
        var customGames: [GameDefinition]
        var matches: [Match]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var activeMatch: Match? { matches.first { !$0.isFinished } }
    var finishedMatches: [Match] { matches.filter(\.isFinished) }

    func match(id: UUID) -> Match? { matches.first { $0.id == id } }

    // MARK: - Players

    /// Adds a player, or returns the existing one with the same name.
    @discardableResult
    func addPlayer(named rawName: String) -> Player? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = players.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let usedColors = Set(players.map(\.colorIndex))
        let color = (0..<PlayerPalette.colors.count).first { !usedColors.contains($0) }
            ?? players.count % PlayerPalette.colors.count
        let player = Player(name: name, colorIndex: color)
        players.append(player)
        save()
        return player
    }

    func deletePlayer(_ player: Player) {
        players.removeAll { $0.id == player.id }
        save()
    }

    func stats(for player: Player) -> (played: Int, wins: Int) {
        let played = finishedMatches.filter { $0.participants.contains { $0.id == player.id } }
        let wins = played.filter { $0.leaders.contains { $0.id == player.id } }
        return (played.count, wins.count)
    }

    /// Players from the most recent match, so the same group doesn't have to be picked every time.
    var lastGroup: [UUID] {
        guard let recent = matches.first else { return [] }
        let roster = Set(players.map(\.id))
        return recent.participants.map(\.id).filter(roster.contains)
    }

    // MARK: - Custom games

    func saveCustomGame(_ game: GameDefinition) {
        guard game.isCustom else { return }
        if let index = customGames.firstIndex(where: { $0.id == game.id }) {
            customGames[index] = game
        } else {
            customGames.insert(game, at: 0)
        }
        save()
    }

    func deleteCustomGame(_ game: GameDefinition) {
        customGames.removeAll { $0.id == game.id }
        save()
    }

    // MARK: - Matches

    /// Starts a match and presents its scoreboard. Any unfinished match is finished and kept in history.
    @discardableResult
    func startMatch(game: GameDefinition, players: [Player]) -> Match {
        if let active = activeMatch {
            mutateMatch(active.id) { $0.finish() }
        }
        let match = Match(game: game, players: players)
        matches.insert(match, at: 0)
        trimHistory()
        save()
        presentedMatchID = match.id
        return match
    }

    func rematch(_ matchID: UUID) {
        guard let old = match(id: matchID) else { return }
        let players = old.participants.map { Player(id: $0.id, name: $0.name, colorIndex: $0.colorIndex) }
        startMatch(game: old.game, players: players)
    }

    func record(_ delta: Int, for participantID: UUID, in matchID: UUID) {
        mutateMatch(matchID) { $0.apply(delta, to: participantID) }
    }

    func undo(in matchID: UUID) {
        mutateMatch(matchID) { $0.undo() }
    }

    func finish(_ matchID: UUID) {
        mutateMatch(matchID) { $0.finish() }
    }

    func deleteMatch(_ matchID: UUID) {
        matches.removeAll { $0.id == matchID }
        save()
    }

    private func mutateMatch(_ id: UUID, _ change: (inout Match) -> Void) {
        guard let index = matches.firstIndex(where: { $0.id == id }) else { return }
        change(&matches[index])
        save()
    }

    private func trimHistory() {
        if matches.count > Self.maxStoredMatches {
            matches.removeLast(matches.count - Self.maxStoredMatches)
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        players = state.players
        customGames = state.customGames
        matches = state.matches
    }

    private func save() {
        let state = PersistedState(players: players, customGames: customGames, matches: matches)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
