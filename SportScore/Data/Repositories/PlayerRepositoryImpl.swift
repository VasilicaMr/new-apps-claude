import SwiftData
import Foundation

final class PlayerRepositoryImpl: PlayerRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [Player] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PlayerModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func save(_ player: Player) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PlayerModel>(
            predicate: #Predicate { $0.id == player.id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.name = player.name
            existing.avatarData = player.avatarData
        } else {
            let model = PlayerModel(id: player.id, name: player.name, avatarData: player.avatarData)
            context.insert(model)
        }
        try context.save()
    }

    func delete(id: UUID) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PlayerModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }
}
