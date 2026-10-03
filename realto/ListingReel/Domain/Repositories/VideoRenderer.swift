import Foundation

/// Progress for a single aspect-ratio render, plus overall fraction.
struct RenderProgress: Equatable {
    var currentAspectRatio: AspectRatio
    var currentFormatIndex: Int
    var totalFormats: Int
    var fractionComplete: Double        // 0...1 overall across all formats

    var overallPercent: Int { Int((fractionComplete * 100).rounded()) }
}

/// THE SEAM (spec §3.5). The Domain depends on this protocol; the only concrete
/// implementation that imports AVFoundation lives in the Data layer.
protocol VideoRenderer {
    /// Assembles a composition and exports one file per requested aspect ratio.
    /// `narration` is an optional voiceover audio file mixed over the music/clip audio.
    /// Emits progress. Throws `RenderError` on failure. Honors cooperative cancellation.
    func export(
        project: Project,
        template: Template,
        brand: BrandProfile?,
        music: MusicTrack?,
        narration: URL?,
        settings: ExportSettings,
        progress: @escaping @Sendable (RenderProgress) -> Void
    ) async throws -> [ExportedFile]
}
