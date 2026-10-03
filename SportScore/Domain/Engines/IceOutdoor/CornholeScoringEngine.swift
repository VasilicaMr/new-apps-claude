import Foundation

struct CornholeConfig: Codable, Sendable {
    var pointsToWin: Int = 21
    var bustRule: Bool = false
}

final class CornholeScoringEngine: ScoringEngine {
    let sport: SportType = .cornhole

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: CornholeConfig.self) ?? CornholeConfig()
        let prevTotal = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        let newTotal = prevTotal + entry.value

        if config.bustRule && newTotal > config.pointsToWin {
            return ScoringResult(
                displayScore: DisplayScore(primary: "\(prevTotal)", secondary: "BUST — reverted"),
                isBust: true,
                notes: "Over \(config.pointsToWin)"
            )
        }

        let isWin = newTotal >= config.pointsToWin
        let label = entry.value == 3 ? "Hole!" : entry.value == 1 ? "Board" : "Cancel"
        return ScoringResult(
            displayScore: DisplayScore(primary: "\(newTotal)", secondary: label),
            isGameOver: isWin,
            winner: isWin ? playerID : nil
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: CornholeConfig.self) ?? CornholeConfig()
        return session.players.contains {
            session.allEntries(for: $0.id).reduce(0) { $0 + $1.value } >= config.pointsToWin
        }
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: "\(total)")
    }
}
