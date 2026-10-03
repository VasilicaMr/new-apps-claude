import Foundation

struct ScoreWidgetEntry: Codable, Sendable {
    let date: Date
    let sessionID: String
    let sportName: String
    let sportIcon: String
    let playerScores: [PlayerWidgetScore]

    static let placeholder = ScoreWidgetEntry(
        date: .now,
        sessionID: "",
        sportName: "Darts",
        sportIcon: "target",
        playerScores: [
            PlayerWidgetScore(playerID: "1", playerName: "Player 1", scoreDisplay: "301"),
            PlayerWidgetScore(playerID: "2", playerName: "Player 2", scoreDisplay: "245")
        ]
    )
}

struct PlayerWidgetScore: Codable, Identifiable, Sendable {
    let playerID: String
    let playerName: String
    let scoreDisplay: String
    var id: String { playerID }
}
