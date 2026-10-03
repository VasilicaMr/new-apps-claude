import AVFoundation
import Photos

/// Resolves a domain `MediaClip` into a concrete `AVAsset` at render time.
/// This is the ONLY place that reads bytes from Photos (spec §5: we never copy
/// raw video into app storage; we resolve on demand).
struct AVAssetResolver {

    private let stillGenerator = StillImageVideoGenerator()

    /// Video → the PHAsset's AVAsset. Photo → a freshly generated still-video segment.
    /// File-backed clips (in-app recordings) use "file:/path" as their sourceIdentifier.
    /// `stillSize` bounds photo-segment memory (we don't render photos at 4K).
    func resolve(_ clip: MediaClip, stillSize: CGSize) async throws -> AVAsset {
        // File-backed clips: in-app recordings, and the Photos-import fallback used
        // when a picked item has no PHAsset identifier available (see MediaStepView).
        if clip.sourceIdentifier.hasPrefix("file:") {
            let path = String(clip.sourceIdentifier.dropFirst(5))
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                throw RenderError.sourceUnavailable(clipID: clip.id)
            }
            switch clip.kind {
            case .video:
                return AVURLAsset(url: url)
            case .photo:
                guard let image = PlatformImage(contentsOfFile: path) else {
                    throw RenderError.sourceUnavailable(clipID: clip.id)
                }
                let generatedURL = try await stillGenerator.makeVideo(
                    from: image, duration: clip.stillDuration, size: stillSize)
                return AVURLAsset(url: generatedURL)
            }
        }

        // PHAsset path (normal import).
        guard let phAsset = phAsset(for: clip.sourceIdentifier) else {
            throw RenderError.sourceUnavailable(clipID: clip.id)
        }

        switch clip.kind {
        case .video:
            return try await requestAVAsset(phAsset, clipID: clip.id)
        case .photo:
            let image = try await requestImage(phAsset, targetSize: stillSize, clipID: clip.id)
            let url = try await stillGenerator.makeVideo(
                from: image, duration: clip.stillDuration, size: stillSize)
            return AVURLAsset(url: url)
        }
    }

    // MARK: - PhotoKit plumbing

    private func phAsset(for localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private func requestAVAsset(_ asset: PHAsset, clipID: UUID) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false      // strictly on-device (offline pitch)
        options.deliveryMode = .highQualityFormat

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    continuation.resume(throwing: inCloud
                        ? RenderError.sourceUnavailable(clipID: clipID)
                        : RenderError.unreadableTrack(clipID: clipID))
                }
            }
        }
    }

    private func requestImage(_ asset: PHAsset, targetSize: CGSize, clipID: UUID) async throws -> PlatformImage {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.resizeMode = .exact

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize,
                contentMode: .aspectFill, options: options
            ) { image, info in
                // requestImage may call back twice (degraded + full); take the first non-nil.
                guard !resumed else { return }
                if let image {
                    resumed = true
                    continuation.resume(returning: image)
                } else if (info?[PHImageErrorKey]) != nil {
                    resumed = true
                    continuation.resume(throwing: RenderError.sourceUnavailable(clipID: clipID))
                }
            }
        }
    }
}
