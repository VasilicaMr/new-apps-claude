//
//  CompleteStopUseCase.swift
//  TrailDomain
//

import Foundation

/// Scores a finished play-through and saves it: stars always add to the total,
/// the per-stop best only goes up.
public struct CompleteStopUseCase {
    private let progress: ProgressRepository

    public init(progress: ProgressRepository) {
        self.progress = progress
    }

    @discardableResult
    public func execute(_ session: SortSession) -> StopResult {
        let stopID = session.stop.id
        let stars = StarRating.stars(forMistakes: session.mistakes)
        let isNewBest = stars > progress.bestStars(for: stopID)
        if isNewBest { progress.setBestStars(stars, for: stopID) }

        let total = progress.totalStars() + stars
        progress.setTotalStars(total)
        return StopResult(stars: stars, isNewBest: isNewBest, totalStars: total)
    }
}
