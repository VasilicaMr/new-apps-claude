import Foundation

struct GameSession: Identifiable, Sendable {
    let id: UUID
    let sport: SportType
    var variant: String?
    var players: [Player]
    var frames: [ScoreFrame]
    var isActive: Bool
    var startedAt: Date
    var endedAt: Date?
    var winnerID: UUID?
    var configJSON: Data?

    init(
        id: UUID = UUID(),
        sport: SportType,
        variant: String? = nil,
        players: [Player] = [],
        configJSON: Data? = nil
    ) {
        self.id = id
        self.sport = sport
        self.variant = variant
        self.players = players
        self.frames = []
        self.isActive = true
        self.startedAt = .now
        self.configJSON = configJSON
    }

    func config<T: Decodable>(as type: T.Type) -> T? {
        guard let data = configJSON else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func frames(for playerID: UUID) -> [ScoreFrame] {
        frames.filter { $0.playerID == playerID }.sorted { $0.frameIndex < $1.frameIndex }
    }

    func allEntries(for playerID: UUID) -> [ScoreEntry] {
        frames(for: playerID).flatMap { $0.entries }
    }

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}
