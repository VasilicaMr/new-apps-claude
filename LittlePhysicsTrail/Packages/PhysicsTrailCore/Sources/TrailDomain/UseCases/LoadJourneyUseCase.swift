//
//  LoadJourneyUseCase.swift
//  TrailDomain
//

import Foundation

/// Builds the journey map: every stop with its best stars and lock state, plus the suggested next stop.
public struct LoadJourneyUseCase {
    private let stops: StopRepository
    private let progress: ProgressRepository
    private let entitlements: EntitlementProvider
    private let policy: AccessPolicy

    public init(stops: StopRepository, progress: ProgressRepository,
                entitlements: EntitlementProvider, policy: AccessPolicy = .standard) {
        self.stops = stops
        self.progress = progress
        self.entitlements = entitlements
        self.policy = policy
    }

    public func execute() -> Journey {
        let owns = entitlements.ownsFullJourney
        let entries = stops.allStops().enumerated().map { index, stop in
            StopProgress(
                stop: stop,
                bestStars: progress.bestStars(for: stop.id),
                isLocked: policy.isLocked(stopAt: index, ownsFullJourney: owns)
            )
        }
        return Journey(
            stops: entries,
            totalStars: progress.totalStars(),
            nextStopID: entries.first { !$0.isCompleted && !$0.isLocked }?.id
        )
    }
}
