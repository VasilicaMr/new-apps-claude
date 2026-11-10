//
//  UserDefaultsProgressRepository.swift
//  TrailData
//

import Foundation
import TrailDomain

public final class UserDefaultsProgressRepository: ProgressRepository {
    private enum Keys {
        static let prefix = "physics.progress."
        static let totalStars = prefix + "stars"
        static func best(_ stopID: String) -> String { prefix + "best." + stopID }
        static func intro(_ stopID: String) -> String { prefix + "intro." + stopID }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func bestStars(for stopID: String) -> Int { defaults.integer(forKey: Keys.best(stopID)) }
    public func setBestStars(_ stars: Int, for stopID: String) { defaults.set(stars, forKey: Keys.best(stopID)) }

    public func totalStars() -> Int { defaults.integer(forKey: Keys.totalStars) }
    public func setTotalStars(_ stars: Int) { defaults.set(stars, forKey: Keys.totalStars) }

    public func hasSeenIntro(for stopID: String) -> Bool { defaults.bool(forKey: Keys.intro(stopID)) }
    public func markIntroSeen(for stopID: String) { defaults.set(true, forKey: Keys.intro(stopID)) }

    public func reset() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Keys.prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
