import SwiftData
import Foundation

final class ScoreRepositoryImpl: ScoreRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func addEntry(_ entry: ScoreEntry, toFrameID: UUID) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ScoreFrameModel>(
            predicate: #Predicate { $0.id == toFrameID }
        )
        guard let frame = try context.fetch(descriptor).first else { return }
        let model = ScoreEntryModel(
            id: entry.id,
            value: entry.value,
            label: entry.label,
            metadata: entry.metadata,
            timestamp: entry.timestamp
        )
        model.frame = frame
        frame.entries.append(model)
        frame.subtotal = frame.entries.reduce(0) { $0 + $1.value }
        context.insert(model)
        try context.save()
    }

    func addFrame(_ frame: ScoreFrame, toSessionID: UUID) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GameSessionModel>(
            predicate: #Predicate { $0.id == toSessionID }
        )
        guard let session = try context.fetch(descriptor).first else { return }
        let model = ScoreFrameModel(
            id: frame.id,
            frameIndex: frame.frameIndex,
            playerID: frame.playerID,
            timestamp: frame.timestamp
        )
        model.session = session
        session.frames.append(model)
        context.insert(model)
        try context.save()
    }

    func undoLastEntry(inSessionID: UUID, forPlayerID: UUID) async throws -> ScoreEntry? {
        let context = ModelContext(container)
        let playerID = forPlayerID
        let sessionID = inSessionID
        let descriptor = FetchDescriptor<ScoreFrameModel>(
            predicate: #Predicate { $0.playerID == playerID && $0.session?.id == sessionID },
            sortBy: [SortDescriptor(\.frameIndex, order: .reverse)]
        )
        let frames = try context.fetch(descriptor)
        guard let lastFrame = frames.first,
              let lastEntry = lastFrame.entries.sorted(by: { $0.timestamp < $1.timestamp }).last else {
            return nil
        }
        let domain = lastEntry.toDomain()
        context.delete(lastEntry)
        lastFrame.subtotal = lastFrame.entries.reduce(0) { $0 + $1.value }
        if lastFrame.entries.isEmpty { context.delete(lastFrame) }
        try context.save()
        return domain
    }

    func fetchFrames(forSessionID: UUID) async throws -> [ScoreFrame] {
        let context = ModelContext(container)
        let id = forSessionID
        let descriptor = FetchDescriptor<ScoreFrameModel>(
            predicate: #Predicate { $0.session?.id == id },
            sortBy: [SortDescriptor(\.frameIndex)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }
}
