import AVFoundation
import QuartzCore

/// Shared assembly logic used by BOTH the exporter and the live preview so the
/// preview reflects the real render (spec §6: "Preview must reflect the real render").
struct CompositionAssembler {

    struct Segment {
        let timeRange: CMTimeRange
        let orientedSize: CGSize
        let preferredTransform: CGAffineTransform
    }

    struct Assembled {
        let composition: AVMutableComposition
        let videoTrack: AVMutableCompositionTrack
        let segments: [Segment]
        let totalDuration: CMTime
        /// Ducks the music/clip audio under the voiceover; nil when there's no narration.
        /// Must be set on the export session / player item alongside the composition.
        let audioMix: AVAudioMix?
    }

    /// The voiceover starts just after the video does, not on its very first frame.
    static let narrationLeadIn = CMTime(value: 1, timescale: 2)
    /// Music/clip audio level while the voiceover speaks.
    static let duckedVolume: Float = 0.25
    private static let duckRamp = CMTime(value: 1, timescale: 2)

    let resolver: AVAssetResolver
    private let overlayFactory = OverlayLayerFactory()

    /// Lays clips end-to-end on one video track (orientation-safe), attaches audio, and
    /// mixes an optional voiceover `narration` audio file over it.
    func assemble(
        project: Project, music: MusicTrack?, narration: URL? = nil,
        stillSize: CGSize, useSourceAudioIfNoMusic: Bool
    ) async throws -> Assembled {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw RenderError.compositionFailed(reason: String(localized: "Could not create a video track."))
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let useSourceAudio = useSourceAudioIfNoMusic && (music == nil)
        var segments: [Segment] = []
        var cursor = CMTime.zero

        for clip in project.orderedClips {
            try Task.checkCancellation()

            let asset = try await resolver.resolve(clip, stillSize: stillSize)
            guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
                throw RenderError.unreadableTrack(clipID: clip.id)
            }
            let fullDuration = try await asset.load(.duration)
            let range = Self.trimRange(clip, fullDuration: fullDuration)

            do {
                try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
            } catch {
                throw RenderError.compositionFailed(reason: error.localizedDescription)
            }

            if useSourceAudio,
               let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack?.insertTimeRange(range, of: sourceAudio, at: cursor)
            }

            let transform = try await sourceVideo.load(.preferredTransform)
            let naturalSize = try await sourceVideo.load(.naturalSize)
            segments.append(Segment(
                timeRange: CMTimeRange(start: cursor, duration: range.duration),
                orientedSize: Self.orientedSize(naturalSize, transform),
                preferredTransform: transform))

            cursor = cursor + range.duration
        }

        guard cursor > .zero else { throw RenderError.noClips }

        if let music, let audioTrack, let url = Self.musicURL(for: music) {
            try? await Self.attachMusic(url: url, to: audioTrack, total: cursor)
        }

        var audioMix: AVAudioMix?
        if let narration,
           let narrationTrack = composition.addMutableTrack(
               withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            // A voiceover that won't load shouldn't sink the render — just leave it out.
            if let spoken = try? await Self.attachNarration(url: narration, to: narrationTrack, total: cursor) {
                audioMix = audioTrack.map { Self.duckingMix(background: $0, under: spoken, total: cursor) }
            } else {
                composition.removeTrack(narrationTrack)
            }
        }

        return Assembled(composition: composition, videoTrack: videoTrack,
                         segments: segments, totalDuration: cursor, audioMix: audioMix)
    }

    /// Builds the per-aspect-ratio video composition: renderSize + fill/fit transforms +
    /// (optionally) the Core Animation overlay tree.
    ///
    /// Pass `forPreview: true` when the result will be set on an `AVPlayerItem`.
    /// `AVVideoCompositionCoreAnimationTool` is export-only and throws a hard exception
    /// if attached to a player item, so the CA overlay is omitted from preview builds.
    /// Clip geometry (transforms, render size, background colours) is identical in both modes.
    func makeVideoComposition(
        assembled: Assembled, renderSize: CGSize, template: Template,
        brand: BrandProfile?, property: PropertyInfo, logo: PlatformImage?,
        includeWatermark: Bool, forPreview: Bool = false
    ) -> AVMutableVideoComposition {
        let vc = AVMutableVideoComposition()
        vc.renderSize = renderSize
        vc.frameDuration = CMTime(value: 1, timescale: 30)

        vc.instructions = assembled.segments.map { segment in
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = segment.timeRange
            instruction.backgroundColor = PlatformColor(hex: template.colorTokens.backgroundHex).cgColor

            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: assembled.videoTrack)
            let transform = Self.transform(
                orientedSize: segment.orientedSize, renderSize: renderSize,
                preferredTransform: segment.preferredTransform, mode: template.body.contentMode)
            layer.setTransform(transform, at: segment.timeRange.start)
            instruction.layerInstructions = [layer]
            return instruction
        }

        // AVVideoCompositionCoreAnimationTool is forbidden on AVPlayerItem; skip for preview.
        guard !forPreview else { return vc }

        let parentLayer = CALayer()
        let videoLayer  = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame  = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)

        let overlay = overlayFactory.makeOverlayLayer(.init(
            template: template, brand: brand, property: property, logo: logo,
            renderSize: renderSize,
            introDuration: template.intro.duration,
            outroDuration: template.outro.duration,
            totalDuration: assembled.totalDuration.seconds,
            includeWatermark: includeWatermark))
        parentLayer.addSublayer(overlay)

        vc.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        return vc
    }

    // MARK: - Math & helpers (orientation-safe, spec §4.1)

    static func orientedSize(_ natural: CGSize, _ transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    static func transform(
        orientedSize: CGSize, renderSize: CGSize,
        preferredTransform: CGAffineTransform, mode: ClipContentMode
    ) -> CGAffineTransform {
        guard orientedSize.width > 0, orientedSize.height > 0 else { return preferredTransform }
        let sx = renderSize.width / orientedSize.width
        let sy = renderSize.height / orientedSize.height
        let scale = (mode == .fill) ? max(sx, sy) : min(sx, sy)
        let scaledW = orientedSize.width * scale
        let scaledH = orientedSize.height * scale
        let tx = (renderSize.width - scaledW) / 2
        let ty = (renderSize.height - scaledH) / 2
        return preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }

    static func trimRange(_ clip: MediaClip, fullDuration: CMTime) -> CMTimeRange {
        let scale: CMTimeScale = 600
        let start = clip.trimStart.map { CMTime(seconds: $0, preferredTimescale: scale) } ?? .zero
        let end = clip.trimEnd.map { CMTime(seconds: $0, preferredTimescale: scale) } ?? fullDuration
        let clampedStart = CMTimeMaximum(.zero, CMTimeMinimum(start, fullDuration))
        let clampedEnd = CMTimeMaximum(clampedStart, CMTimeMinimum(end, fullDuration))
        return CMTimeRange(start: clampedStart, end: clampedEnd)
    }

    static func attachMusic(url: URL, to track: AVMutableCompositionTrack, total: CMTime) async throws {
        let asset = AVURLAsset(url: url)
        guard let source = try await asset.loadTracks(withMediaType: .audio).first else { return }
        let trackDuration = try await asset.load(.duration)
        guard trackDuration > .zero else { return }
        var at = CMTime.zero
        while at < total {
            let take = CMTimeMinimum(trackDuration, total - at)
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: take), of: source, at: at)
            at = at + take
        }
    }

    /// Places the voiceover after the lead-in, cut off at the video's end. Returns the
    /// time range it occupies.
    static func attachNarration(url: URL, to track: AVMutableCompositionTrack, total: CMTime) async throws -> CMTimeRange? {
        let asset = AVURLAsset(url: url)
        guard let source = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let duration = try await asset.load(.duration)
        let start = CMTimeMinimum(narrationLeadIn, total)
        let take = CMTimeMinimum(duration, total - start)
        guard take > .zero else { return nil }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: take), of: source, at: start)
        return CMTimeRange(start: start, duration: take)
    }

    /// Fades the music/clip audio down as the voiceover begins and back up once it ends.
    static func duckingMix(background: AVMutableCompositionTrack, under spoken: CMTimeRange, total: CMTime) -> AVAudioMix {
        let params = AVMutableAudioMixInputParameters(track: background)
        let downStart = CMTimeMaximum(.zero, spoken.start - duckRamp)
        params.setVolumeRamp(fromStartVolume: 1, toEndVolume: duckedVolume,
                             timeRange: CMTimeRange(start: downStart, end: spoken.start))
        let upEnd = CMTimeMinimum(spoken.end + duckRamp, total)
        if upEnd > spoken.end {
            params.setVolumeRamp(fromStartVolume: duckedVolume, toEndVolume: 1,
                                 timeRange: CMTimeRange(start: spoken.end, end: upEnd))
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }

    static func musicURL(for track: MusicTrack) -> URL? {
        let name = (track.fileName as NSString).deletingPathExtension
        let ext = (track.fileName as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "m4a" : ext)
    }
}
