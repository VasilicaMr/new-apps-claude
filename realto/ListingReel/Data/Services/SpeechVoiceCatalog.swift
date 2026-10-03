import Foundation
import AVFoundation

/// `NarrationVoiceCatalog` on `AVSpeechSynthesisVoice`, including the agent's own iPhone
/// Personal Voice once they've granted access to it.
@MainActor
final class SpeechVoiceCatalog: NarrationVoiceCatalog {

    var personalVoiceAccess: PersonalVoiceAccess {
        Self.map(AVSpeechSynthesizer.personalVoiceAuthorizationStatus)
    }

    func requestPersonalVoiceAccess() async -> PersonalVoiceAccess {
        let status = await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { continuation.resume(returning: $0) }
        }
        return Self.map(status)
    }

    func availableVoices(languageCode: String) -> [NarrationVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let personal = all.filter { $0.voiceTraits.contains(.isPersonalVoice) }
        // Premium/enhanced voices sound far better for narration; fall back to whatever the
        // language has. Novelty voices (Bells, Bubbles…) are useless for a listing video.
        let system = all
            .filter { !$0.voiceTraits.contains(.isPersonalVoice) && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .filter { $0.language.hasPrefix(languageCode) }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
        return (personal + system).map {
            NarrationVoice(id: $0.identifier, name: $0.name,
                           isPersonalVoice: $0.voiceTraits.contains(.isPersonalVoice))
        }
    }

    private static func map(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> PersonalVoiceAccess {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .unsupported: return .unsupported
        case .notDetermined: return .notDetermined
        @unknown default: return .unsupported
        }
    }
}
