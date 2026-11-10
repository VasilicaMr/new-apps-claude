//
//  UserDefaultsSettingsRepository.swift
//  TrailData
//

import Foundation
import TrailDomain

public final class UserDefaultsSettingsRepository: SettingsRepository {
    private enum Keys {
        static let readAloud = "physics.settings.readAloud"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// On by default — most players can't read yet.
    public var readAloud: Bool {
        get { defaults.object(forKey: Keys.readAloud) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.readAloud) }
    }
}
