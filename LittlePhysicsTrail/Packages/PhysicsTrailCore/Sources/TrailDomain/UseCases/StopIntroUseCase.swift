//
//  StopIntroUseCase.swift
//  TrailDomain
//

import Foundation

/// The "Big idea" intro is shown automatically on the first visit to a stop only.
public struct StopIntroUseCase {
    private let progress: ProgressRepository

    public init(progress: ProgressRepository) {
        self.progress = progress
    }

    public func shouldShow(_ stop: JourneyStop) -> Bool { !progress.hasSeenIntro(for: stop.id) }
    public func markSeen(_ stop: JourneyStop) { progress.markIntroSeen(for: stop.id) }
}
