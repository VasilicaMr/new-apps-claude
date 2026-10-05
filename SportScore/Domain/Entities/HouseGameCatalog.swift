import Foundation

/// Popular US home games with sensible default rules. Anything not listed can be created
/// as a custom game, and any template can be customized into one.
enum HouseGameCatalog {
    static let all: [HouseGame] = [
        // Card games
        game("Uno", "rectangle.portrait.on.rectangle.portrait.fill", .card, .highestWins, .points, target: 500),
        game("Hearts", "suit.heart.fill", .card, .lowestWins, .points, target: 100),
        game("Spades", "suit.spade.fill", .card, .highestWins, .points, target: 500),
        game("Rummy 500", "suit.club.fill", .card, .highestWins, .points, target: 500),
        game("Gin Rummy", "suit.diamond.fill", .card, .highestWins, .points, target: 100),
        game("Euchre", "suit.club", .card, .highestWins, .points, target: 10),
        game("Pinochle", "suit.diamond", .card, .highestWins, .points, target: 1500),
        game("Canasta", "rectangle.stack.fill", .card, .highestWins, .points, target: 5000),
        game("Phase 10", "10.circle.fill", .card, .lowestWins, .points),
        game("Crazy Eights", "8.circle.fill", .card, .highestWins, .points, target: 100),
        game("Skip-Bo", "rectangle.portrait.fill", .card, .highestWins, .tally),
        game("Go Fish", "fish.fill", .card, .highestWins, .tally),

        // Board games
        game("Monopoly", "house.fill", .board, .highestWins, .tally),
        game("Catan", "hexagon.fill", .board, .highestWins, .tally, target: 10),
        game("Ticket to Ride", "train.side.front.car", .board, .highestWins, .points),
        game("Yahtzee", "die.face.5.fill", .board, .highestWins, .points),
        game("Clue", "magnifyingglass", .board, .highestWins, .tally),
        game("Sorry!", "arrow.uturn.backward.circle.fill", .board, .highestWins, .tally),
        game("Trivial Pursuit", "chart.pie.fill", .board, .highestWins, .tally, target: 6),
        game("Risk", "globe.americas.fill", .board, .highestWins, .tally),
        game("Boggle", "textformat.abc", .board, .highestWins, .points),
        game("Connect 4", "circle.grid.3x3.fill", .board, .highestWins, .tally),
        game("Battleship", "ferry.fill", .board, .highestWins, .tally),

        // Party games
        game("Charades", "theatermasks.fill", .party, .highestWins, .tally),
        game("Pictionary", "paintbrush.pointed.fill", .party, .highestWins, .tally),
        game("Taboo", "nosign", .party, .highestWins, .points),
        game("Heads Up!", "person.crop.rectangle.fill", .party, .highestWins, .points),
        game("Codenames", "eye.fill", .party, .highestWins, .tally),
        game("Apples to Apples", "apple.logo", .party, .highestWins, .tally, target: 7),
        game("Trivia Night", "questionmark.bubble.fill", .party, .highestWins, .tally),
        game("Jenga", "square.stack.3d.up.fill", .party, .highestWins, .tally),
        game("Bingo", "circle.grid.3x3", .party, .highestWins, .tally),
        game("Beer Pong", "cup.and.saucer.fill", .party, .highestWins, .tally, target: 10),

        // Video games
        game("Video Game Wins", "gamecontroller.fill", .video, .highestWins, .tally),
        game("Racing Cup", "flag.checkered", .video, .highestWins, .points),
        game("Fighting Tournament", "figure.boxing", .video, .highestWins, .tally),
        game("Sports Video Game", "sportscourt.fill", .video, .highestWins, .tally),
        game("Party Video Game", "star.circle.fill", .video, .highestWins, .points),
    ]

    static func games(in category: HouseGameCategory) -> [HouseGame] {
        all.filter { $0.category == category }
    }

    /// Icons offered when creating a custom game.
    static let customSymbols = [
        "star.fill", "trophy.fill", "crown.fill", "dice.fill", "suit.spade.fill", "suit.heart.fill",
        "puzzlepiece.fill", "gamecontroller.fill", "flag.checkered", "target", "sportscourt.fill",
        "music.note", "lightbulb.fill", "heart.fill", "bolt.fill", "flame.fill", "house.fill",
        "person.3.fill", "pencil", "questionmark.circle.fill",
    ]

    private static func game(
        _ name: String,
        _ symbol: String,
        _ category: HouseGameCategory,
        _ mode: HouseScoringMode,
        _ entry: HouseEntryStyle,
        target: Int? = nil,
        start: Int = 0
    ) -> HouseGame {
        HouseGame(
            id: "home." + name.lowercased().filter { $0.isLetter || $0.isNumber },
            name: name,
            symbol: symbol,
            category: category,
            rules: HouseGameRules(mode: mode, entry: entry, target: target, startingScore: start)
        )
    }
}
