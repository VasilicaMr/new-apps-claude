import AVFoundation
import Foundation

/// Resolves a clip to an AVAsset, generates thumbnail times, and tracks the
/// trim region the user is adjusting.
@Observable
@MainActor
final class TrimEditorViewModel {

    var asset: AVAsset?
    var duration: TimeInterval = 0
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval = 0
    var isLoading = true
    var errorMessage: String?

    private let clip: MediaClip
    private let resolver: AVAssetResolver

    init(clip: MediaClip, resolver: AVAssetResolver) {
        self.clip = clip
        self.resolver = resolver
        self.trimStart = clip.trimStart ?? 0
    }

    func load() async {
        isLoading = true
        do {
            let asset = try await resolver.resolve(clip, stillSize: CGSize(width: 720, height: 720))
            let dur = try await asset.load(.duration)
            self.asset = asset
            self.duration = dur.seconds
            self.trimEnd = clip.trimEnd ?? dur.seconds
        } catch {
            errorMessage = String(localized: "Couldn't load clip. \(error.localizedDescription)")
        }
        isLoading = false
    }

    var trimmedDuration: TimeInterval { max(0, trimEnd - trimStart) }
    var startFraction: Double { duration > 0 ? trimStart / duration : 0 }
    var endFraction: Double   { duration > 0 ? trimEnd   / duration : 1 }

    func updateStart(fraction: Double) {
        let t = min(fraction * duration, trimEnd - 0.25)
        trimStart = max(0, t)
    }

    func updateEnd(fraction: Double) {
        let t = max(fraction * duration, trimStart + 0.25)
        trimEnd = min(duration, t)
    }

    /// Write trim values back into the caller's MediaClip.
    func apply(to clip: inout MediaClip) {
        clip.trimStart = trimStart > 0 ? trimStart : nil
        clip.trimEnd   = trimEnd < duration - 0.01 ? trimEnd : nil
    }

    static func formatTime(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
