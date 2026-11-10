//
//  ProgressRepository.swift
//  TrailDomain
//

import Foundation

/// The child's saved progress: stars per stop, total stars, and which intros were seen.
public protocol ProgressRepository: AnyObject {
    func bestStars(for stopID: String) -> Int
    func setBestStars(_ stars: Int, for stopID: String)
    func totalStars() -> Int
    func setTotalStars(_ stars: Int)
    func hasSeenIntro(for stopID: String) -> Bool
    func markIntroSeen(for stopID: String)
    /// Wipes stars and intros. Settings are not progress and are kept.
    func reset()
}
