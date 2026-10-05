import Foundation

/// How a game decides who is winning.
enum ScoringMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case highestWins
    case lowestWins
    /// Everyone starts at `startingScore`; entered points are subtracted and the first to 0 wins (e.g. darts 501).
    case countDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highestWins: "Highest score wins"
        case .lowestWins: "Lowest score wins"
        case .countDown: "Count down to zero"
        }
    }
}

/// How scores are entered with the remote.
enum EntryStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Clicking a player adds one point (goals, rounds won, victory points).
    case tally
    /// Clicking a player opens a keypad to enter that round's points.
    case points

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tally: "Click adds 1 point"
        case .points: "Enter points each round"
        }
    }
}

struct GameRules: Codable, Hashable, Sendable {
    var mode: ScoringMode = .highestWins
    var entry: EntryStyle = .tally
    /// Score that ends the game (ignored for `.countDown`, which always ends at 0).
    var target: Int?
    /// Score each player starts at. Only meaningful for `.countDown`.
    var startingScore: Int = 0

    var initialScore: Int { mode == .countDown ? startingScore : 0 }

    var summary: String {
        switch mode {
        case .countDown:
            return "From \(startingScore) down to 0"
        case .highestWins:
            return target.map { "First to \($0)" } ?? "Highest wins"
        case .lowestWins:
            return target.map { "Ends at \($0) · lowest wins" } ?? "Lowest wins"
        }
    }
}

enum GameCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case card, board, party, tableAndYard, video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: "Card Games"
        case .board: "Board Games"
        case .party: "Party Games"
        case .tableAndYard: "Table & Yard"
        case .video: "Video Games"
        }
    }
}

struct GameDefinition: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var symbol: String
    /// `nil` for games the family created themselves.
    var category: GameCategory?
    var rules: GameRules

    var isCustom: Bool { category == nil }

    static func newCustom() -> GameDefinition {
        GameDefinition(id: UUID().uuidString, name: "", symbol: "star.fill", category: nil, rules: GameRules())
    }
}
