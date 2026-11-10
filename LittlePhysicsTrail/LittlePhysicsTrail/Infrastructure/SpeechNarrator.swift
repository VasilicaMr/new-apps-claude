//
//  SpeechNarrator.swift
//  LittlePhysicsTrail
//
//  AVSpeechSynthesizer-backed `Narrator`. Silent when read-aloud is off or under UI tests.
//

import AVFoundation
import TrailDomain

final class SpeechNarrator: Narrator {
    private let synth = AVSpeechSynthesizer()
    private let settings: SettingsRepository
    private let isMuted: Bool

    init(settings: SettingsRepository, isMuted: Bool = false) {
        self.settings = settings
        self.isMuted = isMuted
    }

    func say(_ text: String) {
        guard settings.readAloud, !isMuted else { return }
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.15
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}
