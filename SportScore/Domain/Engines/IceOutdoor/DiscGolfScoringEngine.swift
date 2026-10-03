import Foundation

struct DiscGolfConfig: Codable, Sendable {
    var courseName: String = "Custom Course"
    var holeCount: Int = 18
    var parPerHole: [Int] = Array(repeating: 3, count: 18)
}

final class DiscGolfScoringEngine: ScoringEngine {
    let sport: SportType = .discGolf

    func process(entry: ScoreEntry, for playerID: UUID, in session: GameSession) -> ScoringResult {
        let config = session.config(as: DiscGolfConfig.self) ?? DiscGolfConfig()
        let holeIndex = session.frames(for: playerID).count
        guard holeIndex < config.holeCount else { return .rejected("All \(config.holeCount) holes already played.") }
        let par = holeIndex < config.parPerHole.count ? config.parPerHole[holeIndex] : 3
        let strokes = entry.value
        let relativeToPar = strokes - par
        let totalStrokes = session.allEntries(for: playerID).reduce(0) { $0 + $1.value } + strokes
        let totalPar = config.parPerHole.prefix(holeIndex + 1).reduce(0, +)
        let totalRelative = totalStrokes - totalPar
        let isLastHole = holeIndex + 1 >= config.holeCount

        let label = relativeToPar == -2 ? "Eagle" : relativeToPar == -1 ? "Birdie" :
                    relativeToPar == 0 ? "Par" : relativeToPar == 1 ? "Bogey" : "+\(relativeToPar)"

        if isLastHole {
            // Winner = player with fewest total strokes (after all players finish)
            let allDone = session.players.allSatisfy { p in
                session.frames(for: p.id).count + (p.id == playerID ? 1 : 0) >= config.holeCount
            }
            if allDone {
                let totals: [(UUID, Int)] = session.players.map { p in
                    let t = session.allEntries(for: p.id).reduce(0) { $0 + $1.value } + (p.id == playerID ? strokes : 0)
                    return (p.id, t)
                }
                let minStrokes = totals.min(by: { $0.1 < $1.1 })?.1 ?? 0
                let winnerID = totals.first { $0.1 == minStrokes }?.0
                return ScoringResult(
                    displayScore: DisplayScore(
                        primary: totalRelative >= 0 ? "+\(totalRelative)" : "\(totalRelative)",
                        secondary: "Hole \(holeIndex + 1) · \(label)",
                        detail: "\(totalStrokes) strokes"
                    ),
                    isGameOver: true,
                    winner: winnerID
                )
            }
        }

        return ScoringResult(
            displayScore: DisplayScore(
                primary: totalRelative >= 0 ? "+\(totalRelative)" : "\(totalRelative)",
                secondary: "Hole \(holeIndex + 1) · \(label)",
                detail: "\(totalStrokes) strokes"
            ),
            isGameOver: false
        )
    }

    func isGameOver(_ session: GameSession) -> Bool {
        let config = session.config(as: DiscGolfConfig.self) ?? DiscGolfConfig()
        return session.players.allSatisfy { p in
            session.frames(for: p.id).count >= config.holeCount
        }
    }

    func entryContext(for playerID: UUID, in session: GameSession) -> EntryContext {
        let config = session.config(as: DiscGolfConfig.self) ?? DiscGolfConfig()
        let hole = session.frames(for: playerID).count
        guard hole < config.holeCount else { return EntryContext(prompt: "Round complete", isPlayerFinished: true) }
        let par = hole < config.parPerHole.count ? config.parPerHole[hole] : 3
        return EntryContext(prompt: "Hole \(hole + 1)/\(config.holeCount) · Par \(par)")
    }

    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore {
        let config = session.config(as: DiscGolfConfig.self) ?? DiscGolfConfig()
        let totalStrokes = session.allEntries(for: playerID).reduce(0) { $0 + $1.value }
        let holesPlayed = session.frames(for: playerID).count
        let totalPar = config.parPerHole.prefix(holesPlayed).reduce(0, +)
        let relative = totalStrokes - totalPar
        return DisplayScore(primary: relative >= 0 ? "+\(relative)" : "\(relative)")
    }
}
