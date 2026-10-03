import Foundation

/// Orchestrates a full export: validate → resolve template/brand/music/voiceover → render.
/// Depends only on protocols. Knows nothing about AVFoundation.
struct ExportVideoUseCase {
    let renderer: VideoRenderer
    let templates: TemplateRepository
    let music: MusicRepository
    let brandProfiles: BrandProfileRepository
    let media: MediaRepository
    let narration: NarrateVoiceoverUseCase?

    init(
        renderer: VideoRenderer,
        templates: TemplateRepository,
        music: MusicRepository,
        brandProfiles: BrandProfileRepository,
        media: MediaRepository,
        narration: NarrateVoiceoverUseCase? = nil
    ) {
        self.renderer = renderer
        self.templates = templates
        self.music = music
        self.brandProfiles = brandProfiles
        self.media = media
        self.narration = narration
    }

    /// Renders the project's requested aspect ratios. Emits progress. Throws `RenderError`.
    func callAsFunction(
        project: Project,
        progress: @escaping @Sendable (RenderProgress) -> Void
    ) async throws -> [ExportedFile] {
        guard project.isReadyToExport else { throw RenderError.noClips }

        guard let template = templates.template(id: project.templateID) else {
            throw RenderError.compositionFailed(reason: String(localized: "Template not found."))
        }

        let brand = try await brandProfiles.load()
        let track = project.musicTrackID.flatMap { music.track(id: $0) }
        let narrationAudio = await narration?.audio(for: project)
        defer { narrationAudio.map { try? FileManager.default.removeItem(at: $0) } }

        return try await renderer.export(
            project: project,
            template: template,
            brand: brand,
            music: track,
            narration: narrationAudio,
            settings: project.exportSettings,
            progress: progress
        )
    }

    /// Saves rendered files into the user's photo library (spec §F8).
    func saveToLibrary(_ files: [ExportedFile]) async throws {
        for file in files {
            try await media.saveToPhotoLibrary(fileURL: file.url)
        }
    }
}
