//
//  Narrator.swift
//  TrailDomain
//
//  Reads text aloud for kids who can't read yet. Implemented in the app (AVSpeechSynthesizer);
//  implementations respect `SettingsRepository.readAloud`.
//

import Foundation

public protocol Narrator: AnyObject {
    func say(_ text: String)
    func stop()
}
