import Foundation
import SwiftData

/// SwiftData row. We persist the domain `Project` as an encoded blob so the pure
/// domain struct stays free of `@Model`/persistence concerns (Clean Architecture).
@Model
final class ProjectRecord {
    @Attribute(.unique) var id: UUID
    var blob: Data
    var updatedAt: Date

    init(id: UUID, blob: Data, updatedAt: Date) {
        self.id = id
        self.blob = blob
        self.updatedAt = updatedAt
    }
}

/// Background-safe repository via `@ModelActor` (its own ModelContext).
@ModelActor
actor SwiftDataProjectRepository: ProjectRepository {

    func save(_ project: Project) async throws {
        let blob = try JSONEncoder().encode(project)
        let id = project.id
        let descriptor = FetchDescriptor<ProjectRecord>(predicate: #Predicate { $0.id == id })

        if let existing = try modelContext.fetch(descriptor).first {
            existing.blob = blob
            existing.updatedAt = project.updatedAt
        } else {
            modelContext.insert(ProjectRecord(id: id, blob: blob, updatedAt: project.updatedAt))
        }
        try modelContext.save()
    }

    func fetchAll() async throws -> [Project] {
        let descriptor = FetchDescriptor<ProjectRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let records = try modelContext.fetch(descriptor)
        let decoder = JSONDecoder()
        return records.compactMap { try? decoder.decode(Project.self, from: $0.blob) }
    }

    func fetch(id: Project.ID) async throws -> Project? {
        let descriptor = FetchDescriptor<ProjectRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        return try? JSONDecoder().decode(Project.self, from: record.blob)
    }

    func delete(_ id: Project.ID) async throws {
        let descriptor = FetchDescriptor<ProjectRecord>(predicate: #Predicate { $0.id == id })
        for record in try modelContext.fetch(descriptor) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}
