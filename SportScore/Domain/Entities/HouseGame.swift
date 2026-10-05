import Foundation

/// How a home game decides who is winning.
enum HouseScoringMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case highestWins
    case lowestWins
    /// Everyone starts at `startingScore`; entered points are subtracted and the first to exactly 0 wins.
    case countDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highestWins: "Highest score wins"
        case .lowestWins:  "Lowest score wins"
        case .countDown:   "Count down to zero"
        }
    }
}

/// How scores are entered with the remote.
enum HouseEntryStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Anyone can score at any time; clicking a player adds one point (goals, rounds won, victory points).
    case tally
    /// Players take turns entering that round's points.
    case points

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tally:  "Click a player for +1"
        case .points: "Enter points each turn"
        }
    }
}

struct HouseGameRules: Codable, Hashable, Sendable {
    var mode: HouseScoringMode = .highestWins
    var entry: HouseEntryStyle = .tally
    /// Score that ends the game. Ignored for `.countDown`, which always ends at 0.
    var target: Int?
    /// Score each player starts at. Only used by `.countDown`.
    var startingScore: Int = 0

    var summary: String {
        switch mode {
        case .countDown:   "From \(startingScore) down to 0"
        case .highestWins: target.map { "First to \($0)" } ?? "Highest wins"
        case .lowestWins:  target.map { "Ends at \($0) · lowest wins" } ?? "Lowest wins"
        }
    }
}

enum HouseGameCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case card = "Card Games"
    case board = "Board Games"
    case party = "Party Games"
    case video = "Video Games"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .card:  "suit.heart.fill"
        case .board: "dice.fill"
        case .party: "party.popper.fill"
        case .video: "gamecontroller.fill"
        }
    }
}

/// A home game (built-in template or created by the family), scored by `HouseGameScoringEngine`.
/// A snapshot is stored in each session's `configJSON`, so editing or deleting the game
/// later never changes past results.
struct HouseGame: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var symbol: String
    /// `nil` for custom games created by the user.
    var category: HouseGameCategory?
    var rules: HouseGameRules

    var isCustom: Bool { category == nil }

    static func newCustom() -> HouseGame {
        HouseGame(id: UUID().uuidString, name: "", symbol: "star.fill", category: nil, rules: HouseGameRules())
    }

    /// An editable custom copy of a built-in game ("Customize").
    func customCopy() -> HouseGame {
        HouseGame(id: UUID().uuidString, name: name, symbol: symbol, category: nil, rules: rules)
    }

    var configJSON: Data? { try? JSONEncoder().encode(self) }
}

extension GameSession {
    /// The home/custom game this session plays, if any.
    var houseGame: HouseGame? {
        sport == .houseGame ? config(as: HouseGame.self) : nil
    }

    /// Name shown in lists and on the scoreboard: the game's own name for home/custom games.
    var title: String { houseGame?.name ?? sport.displayName }

    var iconName: String { houseGame?.symbol ?? sport.systemImageName }
}
