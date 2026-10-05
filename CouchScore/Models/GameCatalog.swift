import Foundation

/// Built-in games people commonly play at home, with sensible default rules.
/// Every rule can still be adjusted on the setup screen before starting.
enum GameCatalog {
    static let all: [GameDefinition] = [
        // Card
        preset("Uno", "rectangle.portrait.on.rectangle.portrait.fill", .card, .highestWins, .points, target: 500),
        preset("Hearts", "suit.heart.fill", .card, .lowestWins, .points, target: 100),
        preset("Spades", "suit.spade.fill", .card, .highestWins, .points, target: 500),
        preset("Rummy 500", "suit.club.fill", .card, .highestWins, .points, target: 500),
        preset("Gin Rummy", "suit.diamond.fill", .card, .highestWins, .points, target: 100),
        preset("Euchre", "suit.club", .card, .highestWins, .points, target: 10),
        preset("Cribbage", "rectangle.split.3x1.fill", .card, .highestWins, .points, target: 121),
        preset("Canasta", "rectangle.stack.fill", .card, .highestWins, .points, target: 5000),
        preset("Phase 10", "10.circle.fill", .card, .highestWins, .tally, target: 10),
        preset("Go Fish", "fish.fill", .card, .highestWins, .tally),

        // Board
        preset("Scrabble", "textformat.abc", .board, .highestWins, .points),
        preset("Catan", "hexagon.fill", .board, .highestWins, .tally, target: 10),
        preset("Ticket to Ride", "train.side.front.car", .board, .highestWins, .points),
        preset("Yahtzee", "die.face.5.fill", .board, .highestWins, .points),
        preset("Carcassonne", "map.fill", .board, .highestWins, .points),
        preset("Dominoes", "circle.grid.2x1.fill", .board, .highestWins, .points, target: 150),
        preset("Trivial Pursuit", "chart.pie.fill", .board, .highestWins, .tally, target: 6),
        preset("Backgammon", "circle.lefthalf.filled", .board, .highestWins, .tally, target: 7),
        preset("Chess", "checkerboard.rectangle", .board, .highestWins, .tally),
        preset("Checkers", "circle.circle.fill", .board, .highestWins, .tally),
        preset("Codenames", "eye.fill", .board, .highestWins, .tally),

        // Party
        preset("Charades", "theatermasks.fill", .party, .highestWins, .tally),
        preset("Pictionary", "paintbrush.pointed.fill", .party, .highestWins, .tally),
        preset("Trivia Night", "questionmark.bubble.fill", .party, .highestWins, .tally),
        preset("Heads Up", "person.crop.rectangle.fill", .party, .highestWins, .points),
        preset("Bingo", "circle.grid.3x3.fill", .party, .highestWins, .tally),
        preset("Jenga", "square.stack.3d.up.fill", .party, .highestWins, .tally),
        preset("Rock Paper Scissors", "hand.raised.fill", .party, .highestWins, .tally, target: 3),

        // Table & yard
        preset("Ping Pong", "figure.table.tennis", .tableAndYard, .highestWins, .tally, target: 11),
        preset("Foosball", "soccerball", .tableAndYard, .highestWins, .tally, target: 10),
        preset("Air Hockey", "hockey.puck.fill", .tableAndYard, .highestWins, .tally, target: 7),
        preset("Pool", "8.circle.fill", .tableAndYard, .highestWins, .tally),
        preset("Darts 501", "target", .tableAndYard, .countDown, .points, start: 501),
        preset("Darts 301", "scope", .tableAndYard, .countDown, .points, start: 301),
        preset("Cornhole", "square.fill", .tableAndYard, .highestWins, .points, target: 21),
        preset("Bocce", "circle.hexagongrid.fill", .tableAndYard, .highestWins, .points, target: 12),
        preset("Mini Golf", "figure.golf", .tableAndYard, .lowestWins, .points),
        preset("Bowling", "figure.bowling", .tableAndYard, .highestWins, .points),

        // Video
        preset("Video Game Wins", "gamecontroller.fill", .video, .highestWins, .tally),
        preset("Racing Cup", "flag.checkered", .video, .highestWins, .points),
        preset("Fighting Tournament", "figure.boxing", .video, .highestWins, .tally),
        preset("Sports Video Game", "sportscourt.fill", .video, .highestWins, .tally),
    ]

    static func games(in category: GameCategory) -> [GameDefinition] {
        all.filter { $0.category == category }
    }

    /// Symbols offered when creating a custom game.
    static let customSymbols = [
        "star.fill", "trophy.fill", "crown.fill", "dice.fill", "suit.spade.fill",
        "puzzlepiece.fill", "gamecontroller.fill", "flag.checkered", "target",
        "sportscourt.fill", "music.note", "lightbulb.fill", "heart.fill", "bolt.fill",
    ]

    private static func preset(
        _ name: String,
        _ symbol: String,
        _ category: GameCategory,
        _ mode: ScoringMode,
        _ entry: EntryStyle,
        target: Int? = nil,
        start: Int = 0
    ) -> GameDefinition {
        GameDefinition(
            id: "preset.\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            name: name,
            symbol: symbol,
            category: category,
            rules: GameRules(mode: mode, entry: entry, target: target, startingScore: start)
        )
    }
}
