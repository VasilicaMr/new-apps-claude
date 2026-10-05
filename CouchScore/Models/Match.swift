import Foundation

struct Player: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var colorIndex: Int
}

struct Participant: Codable, Hashable, Identifiable, Sendable {
    /// Same as the roster `Player.id`, so stats can be computed per player.
    var id: UUID
    var name: String
    var colorIndex: Int
    var score: Int
}

struct ScoreChange: Codable, Hashable, Sendable {
    var participantID: UUID
    var delta: Int
}

struct Match: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var game: GameDefinition
    var participants: [Participant]
    /// Ordered score changes, used for undo. Cleared once the match is finished to keep storage small.
    var log: [ScoreChange] = []
    var startedAt = Date()
    var endedAt: Date?

    init(game: GameDefinition, players: [Player]) {
        self.game = game
        self.participants = players.map {
            Participant(id: $0.id, name: $0.name, colorIndex: $0.colorIndex, score: game.rules.initialScore)
        }
    }

    var isFinished: Bool { endedAt != nil }
    var canUndo: Bool { !log.isEmpty && !isFinished }

    mutating func apply(_ delta: Int, to participantID: UUID) {
        guard delta != 0, let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        participants[index].score += delta
        log.append(ScoreChange(participantID: participantID, delta: delta))
    }

    mutating func undo() {
        guard let last = log.popLast(),
              let index = participants.firstIndex(where: { $0.id == last.participantID }) else { return }
        participants[index].score -= last.delta
    }

    mutating func finish() {
        endedAt = Date()
        log = []
    }

    /// Participants ordered best first.
    var standings: [Participant] {
        participants.sorted { lhs, rhs in
            game.rules.mode == .highestWins ? lhs.score > rhs.score : lhs.score < rhs.score
        }
    }

    /// Everyone sharing the best score. Empty when all players are tied (nobody is ahead).
    var leaders: [Participant] {
        guard let best = standings.first?.score else { return [] }
        let top = participants.filter { $0.score == best }
        return top.count == participants.count && participants.count > 1 ? [] : top
    }

    /// True once the game's end condition is met (someone hit the target, or reached 0 when counting down).
    var reachedTarget: Bool {
        switch game.rules.mode {
        case .countDown:
            return participants.contains { $0.score <= 0 }
        case .highestWins, .lowestWins:
            guard let target = game.rules.target else { return false }
            return participants.contains { $0.score >= target }
        }
    }

    var winnerText: String {
        let names = leaders.map(\.name)
        switch names.count {
        case 0: return "It's a tie!"
        case 1: return "\(names[0]) wins!"
        default: return "\(names.formatted(.list(type: .and))) tie!"
        }
    }
}
