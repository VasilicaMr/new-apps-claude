import Foundation

/// Produces the voiceover audio for a render — but only when the AI voiceover is available
/// on this device (iOS 27 / macOS 27+ with Apple Intelligence) and the project has a script.
/// Anything else, including a speech failure, yields nil and the video renders without
/// narration rather than failing the whole export.
struct NarrateVoiceoverUseCase {
    let writer: VoiceoverScriptWriter
    let renderer: NarrationAudioRenderer

    func willNarrate(_ project: Project) -> Bool {
        writer.isAvailable && (project.voiceover?.hasScript ?? false)
    }

    func audio(for project: Project) async -> URL? {
        guard willNarrate(project), let voiceover = project.voiceover else { return nil }
        return try? await renderer.renderAudio(
            script: voiceover.script.trimmingCharacters(in: .whitespacesAndNewlines),
            voiceID: voiceover.voiceID)
    }
}
