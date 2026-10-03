import Foundation

/// User-surfaceable rendering failures. The pipeline must NEVER fail silently
/// (spec §4.4) — every failure maps to one of these with a clear message.
enum RenderError: LocalizedError, Equatable {
    case noClips
    case sourceUnavailable(clipID: UUID)
    case unreadableTrack(clipID: UUID)
    case compositionFailed(reason: String)
    case exportFailed(reason: String)
    case cancelled
    case outOfMemory
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noClips:
            return String(localized: "Add at least one clip or photo before exporting.")
        case .sourceUnavailable:
            return String(localized: "One of your clips is no longer available in Photos. Re-import it and try again.")
        case .unreadableTrack:
            return String(localized: "A clip couldn't be read. It may be an unsupported format.")
        case .compositionFailed(let reason):
            return String(localized: "We couldn't assemble the video: \(reason)")
        case .exportFailed(let reason):
            return String(localized: "The export failed: \(reason)")
        case .cancelled:
            return String(localized: "Export cancelled.")
        case .outOfMemory:
            return String(localized: "This project is too large to render at 4K on this device. Try 1080p.")
        case .unknown(let message):
            return message
        }
    }

    /// Whether offering a retry button makes sense.
    var isRetryable: Bool {
        switch self {
        case .cancelled, .noClips: return false
        default: return true
        }
    }
}
