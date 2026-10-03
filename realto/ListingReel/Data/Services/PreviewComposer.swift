import AVFoundation

/// Builds a lightweight, playable `AVPlayerItem` using the SAME assembly path as
/// the exporter, so the preview matches the final render (spec §6). Rendered at a
/// small size for smooth scrubbing on-device.
final class PreviewComposer {

    private let assembler: CompositionAssembler
    private var brandRepository: BrandProfileRepository?

    init(resolver: AVAssetResolver, brandRepository: BrandProfileRepository? = nil) {
        self.assembler = CompositionAssembler(resolver: resolver)
        self.brandRepository = brandRepository
    }

    /// Returns a preview player item for the given project, or throws `RenderError`.
    /// `narration` (voiceover audio) must stay on disk while the item plays.
    func makePreviewItem(
        project: Project, template: Template, brand: BrandProfile?, music: MusicTrack?,
        narration: URL? = nil
    ) async throws -> AVPlayerItem {
        guard project.isReadyToExport else { throw RenderError.noClips }

        // Preview uses the first requested ratio (default vertical) at a size
        // well below the real export — full export resolution (1080p/4K)
        // would make scrubbing sluggish for no visible benefit on a phone
        // screen. macOS previews render larger: the window (and its
        // Retina display) can actually resolve the extra detail, where an
        // iPhone-sized preview box can't tell 720 from 1080 apart anyway.
        let ratio = project.exportSettings.previewAspectRatio
        #if os(macOS)
        let long: CGFloat = 1080
        #else
        let long: CGFloat = 720
        #endif
        let renderSize: CGSize
        switch ratio {
        case .vertical9x16: renderSize = CGSize(width: AspectRatio.even(long * 9 / 16), height: long)
        case .square1x1:    renderSize = CGSize(width: long, height: long)
        case .wide16x9:     renderSize = CGSize(width: long, height: AspectRatio.even(long * 9 / 16))
        }

        // Same long edge as the video render size, so a photo-only clip
        // isn't the soft spot in an otherwise sharper macOS preview.
        let stillSize = CGSize(width: long, height: long)
        let assembled = try await assembler.assemble(
            project: project, music: music, narration: narration,
            stillSize: stillSize, useSourceAudioIfNoMusic: true)

        let logo = await loadLogo(for: brand)
        // forPreview: true — omits AVVideoCompositionCoreAnimationTool, which is
        // export-only and throws when set on AVPlayerItem.
        let videoComposition = assembler.makeVideoComposition(
            assembled: assembled, renderSize: renderSize, template: template,
            brand: brand, property: project.propertyInfo, logo: logo,
            includeWatermark: project.exportSettings.includeWatermark,
            forPreview: true)

        let item = AVPlayerItem(asset: assembled.composition)
        item.videoComposition = videoComposition
        item.audioMix = assembled.audioMix
        return item
    }

    private func loadLogo(for brand: BrandProfile?) async -> PlatformImage? {
        guard let id = brand?.logoAssetID,
              let data = try? await brandRepository?.loadLogo(id: id) else { return nil }
        return PlatformImage(data: data)
    }
}
