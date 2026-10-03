import Foundation

/// A bundled, licensed music track (spec §5, §8). Auto-fit to video length.
struct MusicTrack: Identifiable, Codable, Equatable {
    typealias ID = String
    let id: ID
    var title: String
    var mood: String                 // "Upbeat", "Cinematic", "Calm"
    var fileName: String             // bundled resource, e.g. "upbeat_01.m4a"
    var durationSeconds: TimeInterval
    var licenseNote: String          // per-track license record (legal exposure §8)
}
