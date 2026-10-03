import Foundation

/// The bundled music library (spec §5, §8). Audio files ship in the app bundle
/// (`Resources/Music`); each track carries a license record. If a file is missing
/// the renderer simply produces a silent (or source-audio) video rather than
/// failing.
///
/// - Important: The three bundled `.m4a` files are original, procedurally
///   composed ambient beds (additive-synthesis pads + algorithmic reverb,
///   built to loop seamlessly since the renderer hard-repeats the file with
///   no crossfade — see `CompositionAssembler.attachMusic`). They are 100%
///   generated in-house, not sampled from any third-party source, so there's
///   no third-party licensing exposure — but they're still a v1 placeholder
///   library rather than professionally produced/mastered music. Consider
///   commissioning or licensing real tracks before a wide release if you want
///   a more polished sound; keep a license record per track either way
///   (spec §8).
struct DefaultMusicRepository: MusicRepository {

    private let tracks: [MusicTrack]

    init() {
        // `licenseNote` is an internal legal record, never shown in the UI — kept in English.
        tracks = [
            MusicTrack(id: "upbeat_01",
                       title: String(localized: "Open House", comment: "Bundled music track name"),
                       mood: String(localized: "Upbeat", comment: "Bundled music track mood"),
                       fileName: "upbeat_01.m4a", durationSeconds: 20,
                       licenseNote: "Original composition, generated in-house (no third-party source). Seamless 20s loop."),
            MusicTrack(id: "cinematic_01",
                       title: String(localized: "Golden Hour", comment: "Bundled music track name"),
                       mood: String(localized: "Cinematic", comment: "Bundled music track mood"),
                       fileName: "cinematic_01.m4a", durationSeconds: 20,
                       licenseNote: "Original composition, generated in-house (no third-party source). Seamless 20s loop."),
            MusicTrack(id: "calm_01",
                       title: String(localized: "Quiet Luxury", comment: "Bundled music track name"),
                       mood: String(localized: "Calm", comment: "Bundled music track mood"),
                       fileName: "calm_01.m4a", durationSeconds: 20,
                       licenseNote: "Original composition, generated in-house (no third-party source). Seamless 20s loop.")
        ]
    }

    func allTracks() -> [MusicTrack] { tracks }

    func track(id: MusicTrack.ID) -> MusicTrack? { tracks.first { $0.id == id } }
}
