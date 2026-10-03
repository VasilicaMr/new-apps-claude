import Foundation

/// Persistence of projects (local only — SwiftData). Domain owns the interface.
protocol ProjectRepository {
    func save(_ project: Project) async throws
    func fetchAll() async throws -> [Project]
    func fetch(id: Project.ID) async throws -> Project?
    func delete(_ id: Project.ID) async throws
}

/// The catalog of bundled templates (JSON-driven, spec §5).
protocol TemplateRepository {
    func allTemplates() -> [Template]
    func template(id: Template.ID) -> Template?
}

/// The catalog of bundled, licensed music.
protocol MusicRepository {
    func allTracks() -> [MusicTrack]
    func track(id: MusicTrack.ID) -> MusicTrack?
}

/// Persistence of the reusable brand profile.
protocol BrandProfileRepository {
    func load() async throws -> BrandProfile?
    func save(_ profile: BrandProfile) async throws
    /// Persists a logo image (raw data) and returns an asset id to reference it.
    func storeLogo(_ data: Data) async throws -> String
    func loadLogo(id: String) async throws -> Data?
}

/// Bridges Photos into domain `MediaClip`s. The AVAsset resolution stays in Data.
protocol MediaRepository {
    /// Requests library authorization if needed. Returns whether granted.
    func requestAuthorization() async -> Bool
    /// Builds MediaClips from PHAsset local identifiers picked by the user.
    func makeClips(fromLocalIdentifiers ids: [String], startingOrder: Int) -> [MediaClip]
    /// Saves a finished export file into the user's photo library.
    func saveToPhotoLibrary(fileURL: URL) async throws
}
