import AVFoundation
#if os(iOS)
import UIKit
#endif

/// The concrete `VideoRenderer` — the ONLY renderer that imports AVFoundation
/// (spec §3.5). Everything above it depends on the protocol, not this class.
///
/// Pipeline (spec §4): assemble one composition → per aspect ratio build a
/// video composition (renderSize + transforms + Core Animation overlays) →
/// export sequentially with `AVAssetExportSession`. HEVC preferred, H.264 fallback.
/// Progress reported, cancellable, never fails silently.
final class AVVideoCompositionService: VideoRenderer {

    private let assembler = CompositionAssembler(resolver: AVAssetResolver())
    private let brandRepository: BrandProfileRepository

    init(brandRepository: BrandProfileRepository) {
        self.brandRepository = brandRepository
    }

    func export(
        project: Project,
        template: Template,
        brand: BrandProfile?,
        music: MusicTrack?,
        narration: URL?,
        settings: ExportSettings,
        progress: @escaping @Sendable (RenderProgress) -> Void
    ) async throws -> [ExportedFile] {
        guard project.isReadyToExport else { throw RenderError.noClips }

        // Photos are bounded to keep memory flat at 4K (spec §4.5).
        let stillSide = min(settings.resolution.longEdge, 1920)
        let stillSize = CGSize(width: stillSide, height: stillSide)

        let assembled = try await assembler.assemble(
            project: project, music: music, narration: narration,
            stillSize: stillSize, useSourceAudioIfNoMusic: true)

        let logo = await loadLogo(for: brand)

        let ratios = settings.aspectRatios.sorted { $0.rawValue < $1.rawValue }
        guard !ratios.isEmpty else {
            throw RenderError.compositionFailed(reason: String(localized: "No aspect ratio selected."))
        }

        var outputs: [ExportedFile] = []
        do {
            for (index, ratio) in ratios.enumerated() {
                try Task.checkCancellation()
                let renderSize = ratio.renderSize(for: settings.resolution)
                let videoComposition = assembler.makeVideoComposition(
                    assembled: assembled, renderSize: renderSize, template: template,
                    brand: brand, property: project.propertyInfo, logo: logo,
                    includeWatermark: settings.includeWatermark)

                let file = try await runExport(
                    composition: assembled.composition, videoComposition: videoComposition,
                    audioMix: assembled.audioMix, ratio: ratio, settings: settings,
                    formatIndex: index, totalFormats: ratios.count, progress: progress)
                outputs.append(file)
            }
        } catch {
            // A later format failing (or cancellation) shouldn't leave earlier
            // successful exports orphaned in the temp directory (spec §4.5).
            for file in outputs {
                try? FileManager.default.removeItem(at: file.url)
            }
            throw error
        }
        return outputs
    }

    // MARK: - Export a single format

    private func runExport(
        composition: AVMutableComposition, videoComposition: AVMutableVideoComposition,
        audioMix: AVAudioMix?, ratio: AspectRatio, settings: ExportSettings,
        formatIndex: Int, totalFormats: Int,
        progress: @escaping @Sendable (RenderProgress) -> Void
    ) async throws -> ExportedFile {

        let preset = Self.preset(for: settings.codec, composition: composition)
        guard let session = AVAssetExportSession(asset: composition, presetName: preset) else {
            throw RenderError.exportFailed(reason: String(localized: "Could not create an export session."))
        }

        let safeRatio = ratio.rawValue.replacingOccurrences(of: ":", with: "x")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("listingreel_\(safeRatio)_\(UUID().uuidString).mp4")

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.audioMix = audioMix
        session.shouldOptimizeForNetworkUse = true

        // A multi-format 4K export can run long enough to be backgrounded; keep
        // the export session alive for a grace period instead of letting iOS
        // suspend it mid-write (a common cause of exports silently never finishing).
        // macOS apps aren't suspended mid-export the same way, so this is iOS-only.
        #if os(iOS)
        let bgTask = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "ListingReel Export") {
                session.cancelExport()
            }
        }
        defer {
            if bgTask != .invalid {
                Task { @MainActor in UIApplication.shared.endBackgroundTask(bgTask) }
            }
        }
        #endif

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await withTaskCancellationHandler {
                        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                            session.exportAsynchronously {
                                switch session.status {
                                case .completed:
                                    cont.resume()
                                case .cancelled:
                                    cont.resume(throwing: RenderError.cancelled)
                                case .failed:
                                    cont.resume(throwing: RenderError.exportFailed(
                                        reason: session.error?.localizedDescription
                                            ?? String(localized: "Unknown export error.")))
                                default:
                                    cont.resume(throwing: RenderError.exportFailed(
                                        reason: String(localized: "Export ended in an unexpected state.")))
                                }
                            }
                        }
                    } onCancel: {
                        session.cancelExport()
                    }
                }
                // Per-format progress by polling (iOS 17 compatible), plus a watchdog:
                // AVAssetExportSession's completion handler can, rarely, never fire
                // (OS bug, or the process was suspended mid-export). Without this the
                // caller would await forever with no way to recover.
                group.addTask {
                    var lastProgress: Float = 0
                    var lastProgressChange = ContinuousClock.now
                    while !Task.isCancelled {
                        let overall = (Double(formatIndex) + Double(session.progress)) / Double(totalFormats)
                        progress(RenderProgress(currentAspectRatio: ratio, currentFormatIndex: formatIndex,
                                                totalFormats: totalFormats, fractionComplete: overall))

                        let now = ContinuousClock.now
                        if session.progress != lastProgress {
                            lastProgress = session.progress
                            lastProgressChange = now
                        } else if now - lastProgressChange > .seconds(90) {
                            session.cancelExport()
                            throw RenderError.exportFailed(
                                reason: String(localized: "Export stalled — no progress for 90 seconds."))
                        }
                        try await Task.sleep(nanoseconds: 150_000_000)
                    }
                }
                defer { group.cancelAll() }
                try await group.next()
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)   // no orphan temp files (§4.5)
            throw error
        }

        progress(RenderProgress(currentAspectRatio: ratio, currentFormatIndex: formatIndex,
                                totalFormats: totalFormats,
                                fractionComplete: Double(formatIndex + 1) / Double(totalFormats)))

        let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = (attributes?[.size] as? Int64) ?? 0
        return ExportedFile(aspectRatio: ratio, url: outputURL, fileSizeBytes: size)
    }

    private static func preset(for codec: VideoCodec, composition: AVComposition) -> String {
        let compatible = AVAssetExportSession.exportPresets(compatibleWith: composition)
        let preferred = (codec == .hevc)
            ? AVAssetExportPresetHEVCHighestQuality
            : AVAssetExportPresetHighestQuality
        return compatible.contains(preferred) ? preferred : AVAssetExportPresetHighestQuality
    }

    private func loadLogo(for brand: BrandProfile?) async -> PlatformImage? {
        guard let id = brand?.logoAssetID,
              let data = try? await brandRepository.loadLogo(id: id) else { return nil }
        return PlatformImage(data: data)
    }
}
