import SwiftData
import Foundation

final class SessionRepositoryImpl: SessionRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [GameSession] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GameSessionModel>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchActive() async throws -> [GameSession] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GameSessionModel>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> GameSession? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GameSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    func save(_ session: GameSession) async throws {
        let context = ModelContext(container)
        let id = session.id
        let descriptor = FetchDescriptor<GameSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.isActive = session.isActive
            existing.endedAt = session.endedAt
            existing.winnerID = session.winnerID
            existing.metadataJSON = session.configJSON
        } else {
            let model = GameSessionModel(id: session.id, sport: session.sport, variant: session.variant)
            model.metadataJSON = session.configJSON
            model.isActive = session.isActive
            model.playerOrder = session.players.map(\.id)
            for player in session.players {
                let playerDescriptor = FetchDescriptor<PlayerModel>(
                    predicate: #Predicate { $0.id == player.id }
                )
                if let pm = try context.fetch(playerDescriptor).first {
                    model.players.append(pm)
                }
            }
            context.insert(model)
        }
        try context.save()
    }

    func delete(id: UUID) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GameSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }
}
