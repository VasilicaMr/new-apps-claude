import Foundation
import Observation

/// Drives the AI voiceover sheet: the agent labels the rooms, Apple Intelligence drafts a
/// ~30-second script, the agent edits it and picks a voice. The narration is then mixed
/// into the preview and the exported video. Edits go straight into the shared
/// `EditorFlowModel.project` so they're autosaved.
@Observable
@MainActor
final class VoiceoverViewModel: Identifiable {
    let editor: EditorFlowModel
    private let writeScript: WriteVoiceoverScriptUseCase
    private let voiceCatalog: NarrationVoiceCatalog

    private(set) var isWriting = false
    private(set) var voices: [NarrationVoice] = []
    private(set) var personalVoiceAccess: PersonalVoiceAccess
    var errorMessage: String?

    /// Room names offered in each clip's menu, in a typical walkthrough order.
    static let roomSuggestions: [String] = [
        String(localized: "Exterior", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Entryway", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Living Room", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Kitchen", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Dining Room", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Primary Bedroom", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Bedroom", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Bathroom", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Office", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Backyard", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "Garage", comment: "Room label for a clip, used by the AI voiceover"),
        String(localized: "View", comment: "Room label for a clip showing the property's view, used by the AI voiceover"),
    ]

    init(editor: EditorFlowModel, writeScript: WriteVoiceoverScriptUseCase, voiceCatalog: NarrationVoiceCatalog) {
        self.editor = editor
        self.writeScript = writeScript
        self.voiceCatalog = voiceCatalog
        self.personalVoiceAccess = voiceCatalog.personalVoiceAccess
        reloadVoices()
    }

    // MARK: - Room order

    var clips: [MediaClip] { editor.project.orderedClips }

    func setRoomLabel(_ label: String?, for clip: MediaClip) {
        guard let index = editor.project.clips.firstIndex(where: { $0.id == clip.id }) else { return }
        editor.project.clips[index].roomLabel = label
        editor.autosave()
    }

    // MARK: - Script

    var script: String {
        get { editor.project.voiceover?.script ?? "" }
        set { editor.project.voiceover = Voiceover(script: newValue, voiceID: selectedVoiceID) }
    }

    var hasScript: Bool { editor.project.voiceover?.hasScript ?? false }
    var estimatedSeconds: Int { WriteVoiceoverScriptUseCase.estimatedSeconds(of: script) }

    func generateScript() async {
        isWriting = true
        errorMessage = nil
        defer { isWriting = false }
        do {
            script = try await writeScript.write(project: editor.project, brand: editor.brand)
            editor.autosave()
        } catch {
            errorMessage = (error as? VoiceoverScriptError)?.errorDescription
                ?? VoiceoverScriptError.failed.errorDescription
        }
    }

    /// Removes the narration from the preview and export.
    func removeVoiceover() {
        editor.project.voiceover = nil
        editor.autosave()
    }

    func scriptEditingEnded() {
        editor.autosave()
    }

    // MARK: - Voice

    var selectedVoiceID: NarrationVoice.ID? {
        get { editor.project.voiceover?.voiceID }
        set {
            editor.project.voiceover = Voiceover(script: script, voiceID: newValue)
            editor.autosave()
        }
    }

    func requestPersonalVoice() async {
        personalVoiceAccess = await voiceCatalog.requestPersonalVoiceAccess()
        reloadVoices()
        if let personal = voices.first(where: \.isPersonalVoice) {
            selectedVoiceID = personal.id
        }
    }

    private func reloadVoices() {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        voices = voiceCatalog.availableVoices(languageCode: language)
        if selectedVoiceID == nil || !voices.contains(where: { $0.id == selectedVoiceID }) {
            // Default to the agent's own voice when they've already set one up.
            selectedVoiceID = voices.first(where: \.isPersonalVoice)?.id ?? voices.first?.id
        }
    }
}
