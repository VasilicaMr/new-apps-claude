import SwiftData
import Foundation

final class CustomGameRepositoryImpl: CustomGameRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [HouseGame] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CustomGameModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func save(_ game: HouseGame) async throws {
        let context = ModelContext(container)
        let id = game.id
        let descriptor = FetchDescriptor<CustomGameModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: game)
        } else {
            context.insert(CustomGameModel(id: game.id, name: game.name, symbol: game.symbol, rules: game.rules))
        }
        try context.save()
    }

    func delete(id: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CustomGameModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }
}
