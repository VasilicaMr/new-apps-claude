//
//  GrownUpsViewModel.swift
//  LittlePhysicsTrail
//

import Foundation
import Observation
import TrailDomain

@MainActor
@Observable
final class GrownUpsViewModel {
    private(set) var journey: Journey
    var readAloud: Bool {
        didSet { settings.readAloud = readAloud }
    }

    private let loadJourney: LoadJourneyUseCase
    private let resetProgress: ResetProgressUseCase
    private let unlock: UnlockJourneyUseCase
    private let settings: SettingsRepository

    init(loadJourney: LoadJourneyUseCase, resetProgress: ResetProgressUseCase,
         unlock: UnlockJourneyUseCase, settings: SettingsRepository) {
        self.loadJourney = loadJourney
        self.resetProgress = resetProgress
        self.unlock = unlock
        self.settings = settings
        self.journey = loadJourney.execute()
        self.readAloud = settings.readAloud
    }

    var ownsFullJourney: Bool { unlock.isUnlocked }
    var price: String? { unlock.offer?.displayPrice }

    func refresh() {
        journey = loadJourney.execute()
    }

    func reset() {
        resetProgress.execute()
        journey = loadJourney.execute()
    }
}
