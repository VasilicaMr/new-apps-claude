//
//  GameProgress.swift
//  ShadowMatch
//
//  Stars earned (total + best per pack) and which pack intros were seen, persisted in UserDefaults.
//

import SwiftUI

final class GameProgress: ObservableObject {
    private enum Keys {
        static let stars = "shadow.stars"
        static let introsSeen = "shadow.introsSeen"
        static func best(_ packID: String) -> String { "shadow.best.\(packID)" }
    }
    private let defaults = UserDefaults.standard

    @Published var stars: Int { didSet { defaults.set(stars, forKey: Keys.stars) } }
    @Published private(set) var bestStars: [String: Int]
    @Published private(set) var introsSeen: Set<String> { didSet { defaults.set(Array(introsSeen), forKey: Keys.introsSeen) } }

    init() {
        let defaults = UserDefaults.standard
        stars = defaults.integer(forKey: Keys.stars)
        bestStars = Dictionary(uniqueKeysWithValues: ShadowPack.all.map { ($0.id, defaults.integer(forKey: Keys.best($0.id))) })
        introsSeen = Set(defaults.stringArray(forKey: Keys.introsSeen) ?? [])
    }

    func best(for pack: ShadowPack) -> Int { bestStars[pack.id] ?? 0 }

    func hasSeenIntro(_ pack: ShadowPack) -> Bool { introsSeen.contains(pack.id) }
    func markIntroSeen(_ pack: ShadowPack) { introsSeen.insert(pack.id) }

    /// Grown-ups hub "Reset progress": stars, bests, intros, tutorials and settings. Purchases live in StoreKit, not here.
    func reset() {
        for key in [Keys.stars, Keys.introsSeen, ShadowStyle.silhouetteKey, NubeeSpeech.enabledKey,
                    "shadow.tutorialDone", TutorialView.doneKey]
            + ShadowPack.all.map({ Keys.best($0.id) }) {
            defaults.removeObject(forKey: key)
        }
        stars = 0
        bestStars = bestStars.mapValues { _ in 0 }
        introsSeen = []
    }

    func record(pack: ShadowPack, stars earned: Int) {
        stars += earned
        if earned > best(for: pack) {
            bestStars[pack.id] = earned
            defaults.set(earned, forKey: Keys.best(pack.id))
        }
    }
}
