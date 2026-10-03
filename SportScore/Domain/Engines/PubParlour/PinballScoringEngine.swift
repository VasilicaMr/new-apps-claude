import Foundation

final class PinballScoringEngine: ScoringEngine {
    let sport: SportType = .pinball

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + entry.value
        let machine = entry.metadata?["machine"] ?? "Unknown"
        return ScoringResult(
            displayScore: DisplayScore(primary: formatScore(total), secondary: machine)
        )
    }

    func isGameOver(_ session: GameSession) -> Bool { false }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let total = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        return DisplayScore(primary: formatScore(total))
    }

    private func formatScore(_ score: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }
}
