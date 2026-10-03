import Foundation

/// Create / load / save / delete projects. Thin orchestration over the repository.
struct ManageProjectsUseCase {
    let repository: ProjectRepository
    let templates: TemplateRepository

    func newProject() -> Project {
        let firstTemplate = templates.allTemplates().first
        return Project(templateID: firstTemplate?.id ?? "classic")
    }

    func all() async throws -> [Project] {
        try await repository.fetchAll().sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ project: Project) async throws {
        var copy = project
        copy.updatedAt = .now
        try await repository.save(copy)
    }

    func delete(_ id: Project.ID) async throws {
        try await repository.delete(id)
    }
}

/// Load and persist the reusable brand profile (spec §F5).
struct ManageBrandProfileUseCase {
    let repository: BrandProfileRepository

    func load() async throws -> BrandProfile {
        try await repository.load() ?? BrandProfile()
    }

    func save(_ profile: BrandProfile) async throws {
        try await repository.save(profile)
    }

    func storeLogo(_ data: Data) async throws -> String {
        try await repository.storeLogo(data)
    }
}

/// Bring media into a project from Photos (spec §F1).
struct ImportMediaUseCase {
    let media: MediaRepository

    func requestAccess() async -> Bool {
        await media.requestAuthorization()
    }

    /// Appends picked assets to a project, preserving order.
    func appendClips(localIdentifiers: [String], to project: inout Project) {
        let startOrder = (project.clips.map(\.order).max() ?? -1) + 1
        let newClips = media.makeClips(fromLocalIdentifiers: localIdentifiers,
                                       startingOrder: startOrder)
        project.clips.append(contentsOf: newClips)
    }
}
