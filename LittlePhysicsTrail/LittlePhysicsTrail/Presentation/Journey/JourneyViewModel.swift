//
//  JourneyViewModel.swift
//  LittlePhysicsTrail
//
//  Home screen state. The owl marker suggests the next unfinished *open* stop and walks on
//  (with a "Next stop" toast) after a stop is finished. Locked stops open the grown-up
//  unlock page behind the parental gate; they are never suggested.
//

import Foundation
import Observation
import TrailDomain

@MainActor
@Observable
final class JourneyViewModel {
    struct LessonRoute: Identifiable {
        let stop: JourneyStop
        let showIntro: Bool
        var id: String { stop.id }
    }

    private(set) var journey: Journey = .empty
    /// Stop the owl stands next to.
    private(set) var markerStopID: String?
    private(set) var toast: String?
    /// Presented full screen while set.
    var lesson: LessonRoute?
    /// Locked stop that was tapped: presents the unlock page while set.
    var unlockRequest: JourneyStop?

    /// Stop to start once the unlock sheet is gone.
    private var stopAfterUnlock: JourneyStop?

    private let loadJourney: LoadJourneyUseCase
    private let intro: StopIntroUseCase
    private let entitlements: EntitlementProvider
    private let narrator: Narrator

    init(loadJourney: LoadJourneyUseCase, intro: StopIntroUseCase, entitlements: EntitlementProvider, narrator: Narrator) {
        self.loadJourney = loadJourney
        self.intro = intro
        self.entitlements = entitlements
        self.narrator = narrator
    }

    /// Observed by the view so the trail refreshes when a purchase lands (also Ask to Buy, restore).
    var ownsFullJourney: Bool { entitlements.ownsFullJourney }

    func onAppear() {
        refresh()
        markerStopID = journey.nextStopID
    }

    func refresh() {
        journey = loadJourney.execute()
    }

    func open(_ stop: JourneyStop) {
        if journey.stops.first(where: { $0.id == stop.id })?.isLocked == true {
            unlockRequest = stop
        } else {
            lesson = LessonRoute(stop: stop, showIntro: intro.shouldShow(stop))
        }
    }

    /// "Start exploring" on the unlock page: close it, then play the stop that was tapped.
    func explore(_ stop: JourneyStop) {
        stopAfterUnlock = stop
        unlockRequest = nil
    }

    func unlockClosed() {
        entitlementsChanged()
        if let stop = stopAfterUnlock {
            stopAfterUnlock = nil
            open(stop)
        }
    }

    /// A purchase can make a new stop the suggestion — move the owl quietly (no toast).
    func entitlementsChanged() {
        refresh()
        if markerStopID == nil { markerStopID = journey.nextStopID }
    }

    /// Grown-ups hub closed: progress may have been reset, so the owl goes back quietly.
    func grownUpsClosed() {
        refresh()
        markerStopID = journey.nextStopID
    }

    /// Back from a stop: if it was finished, move the owl and announce the next stop.
    func lessonClosed() {
        refresh()
        let next = journey.nextStop
        guard next?.id != markerStopID else { return }
        markerStopID = next?.id
        guard let next else { return }

        let message = "Next stop: \(next.title)!"
        toast = message
        narrator.say(message)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.8))
            if self?.toast == message { self?.toast = nil }
        }
    }
}
