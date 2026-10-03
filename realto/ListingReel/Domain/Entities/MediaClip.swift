import Foundation

enum MediaKind: String, Codable, Equatable {
    case video
    case photo
}

/// A reference to a piece of source media — never the media bytes themselves.
/// We store a PHAsset localIdentifier (or a security-scoped bookmark) and
/// resolve it to an AVAsset only at render time (spec §5).
struct MediaClip: Identifiable, Codable, Equatable {
    let id: UUID
    var sourceIdentifier: String     // PHAsset.localIdentifier or bookmark base64
    var kind: MediaKind
    var trimStart: TimeInterval?     // seconds; nil = from start
    var trimEnd: TimeInterval?       // seconds; nil = to natural end
    var order: Int
    /// Which room/area the clip shows ("Kitchen"), when known — set from the capture shot
    /// list or by the agent. Gives the AI voiceover the walkthrough's room order.
    var roomLabel: String?

    /// Fallback on-screen duration for photos (Ken Burns segment length).
    var stillDuration: TimeInterval

    init(
        id: UUID = UUID(),
        sourceIdentifier: String,
        kind: MediaKind,
        trimStart: TimeInterval? = nil,
        trimEnd: TimeInterval? = nil,
        order: Int,
        roomLabel: String? = nil,
        stillDuration: TimeInterval = 3.0
    ) {
        self.id = id
        self.sourceIdentifier = sourceIdentifier
        self.kind = kind
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.order = order
        self.roomLabel = roomLabel
        self.stillDuration = stillDuration
    }
}
