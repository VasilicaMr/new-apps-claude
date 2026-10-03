import Foundation

/// What the model is told about the listing when it writes a voiceover script.
struct VoiceoverScriptRequest: Equatable {
    var propertyInfo: PropertyInfo
    /// The rooms in the order the video shows them, consecutive repeats collapsed.
    var roomOrder: [String]
    var agentName: String?
    var brokerage: String?
    var targetSeconds: Int
    /// Approximate word budget for `targetSeconds` at a relaxed narration pace.
    var targetWordCount: Int
    /// Set when the video announces an open house: its date and time, already formatted
    /// ("Saturday, October 4, 2 – 4 PM") so the model repeats it rather than working out dates.
    var openHouseWhen: String? = nil
}

/// Writes a short narration script for the listing video. Domain owns the interface;
/// the on-device Apple Intelligence model lives in Data.
protocol VoiceoverScriptWriter {
    /// False where the feature isn't offered (OS too old, no Apple Intelligence, or turned
    /// off) — the UI hides the action entirely rather than offering something that can't work.
    var isAvailable: Bool { get }
    func writeScript(for request: VoiceoverScriptRequest) async throws -> String
}

enum VoiceoverScriptError: LocalizedError, Equatable {
    case unavailable
    case missingDetails
    case refused
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "AI voiceover needs Apple Intelligence, which isn't available on this device.")
        case .missingDetails:
            return String(localized: "Add the property's address or details first, so there's something to talk about.")
        case .refused:
            return String(localized: "Couldn't write a script from these details. Try rewording the headline.")
        case .failed:
            return String(localized: "Couldn't write the script. Please try again.")
        }
    }
}

/// A system voice the script can be read in.
struct NarrationVoice: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    /// The agent's own voice, recorded with iPhone's Personal Voice.
    let isPersonalVoice: Bool
}

enum PersonalVoiceAccess: Equatable {
    case notDetermined
    case authorized
    case denied
    case unsupported
}

/// The voices a script can be read in, including the agent's own Personal Voice.
@MainActor
protocol NarrationVoiceCatalog: AnyObject {
    var personalVoiceAccess: PersonalVoiceAccess { get }
    func requestPersonalVoiceAccess() async -> PersonalVoiceAccess
    /// Personal Voices first (when authorized), then the best voices for `languageCode`.
    func availableVoices(languageCode: String) -> [NarrationVoice]
}

/// Speaks a script into an audio file so it can be mixed into the preview and export.
protocol NarrationAudioRenderer {
    /// Returns a temporary audio file; the caller deletes it when done.
    func renderAudio(script: String, voiceID: String?) async throws -> URL
}
