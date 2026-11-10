//
//  LessonViewModel.swift
//  LittlePhysicsTrail
//
//  One visit to a stop: Big Idea intro → sorting game → finish. The rules live in
//  TrailDomain.SortSession; this class adds narration, feedback state and saving.
//

import Foundation
import Observation
import TrailDomain

@MainActor
@Observable
final class LessonViewModel {
    enum Phase: Equatable {
        case intro
        case playing
        case finished(StopResult)
    }

    let stop: JourneyStop
    private(set) var phase: Phase
    private(set) var session: SortSession
    /// Wrong drops per bin; the view shakes a bin whenever its count changes.
    private(set) var wrongDrops: [SortBin.ID: Int] = [:]
    /// True when the Big Idea was reopened from the game (so closing it returns to the game).
    private(set) var isReviewingIdea = false

    private let completeStop: CompleteStopUseCase
    private let intro: StopIntroUseCase
    private let narrator: Narrator

    init(stop: JourneyStop, showIntro: Bool, completeStop: CompleteStopUseCase, intro: StopIntroUseCase, narrator: Narrator) {
        self.stop = stop
        self.phase = showIntro ? .intro : .playing
        self.session = SortSession(stop: stop)
        self.completeStop = completeStop
        self.intro = intro
        self.narrator = narrator
    }

    /// The item whose fact card is showing (just dropped in the right bin).
    var revealedItem: SortItem? { session.awaitingNext ? session.current : nil }
    /// "Drag me" hint until the first correct drop.
    var showsDragHint: Bool { session.placed.isEmpty && session.mistakes == 0 }

    // MARK: Intro

    func readBigIdea() {
        narrator.say("\(stop.bigIdea.headline) \(stop.bigIdea.explanation)")
    }

    func readTryAtHome() {
        narrator.say("Try at home. \(stop.bigIdea.tryAtHome)")
    }

    func startPlaying() {
        intro.markSeen(stop)
        isReviewingIdea = false
        phase = .playing
    }

    func reviewBigIdea() {
        isReviewingIdea = true
        phase = .intro
    }

    // MARK: Game

    func askQuestion() {
        narrator.say(stop.question)
    }

    @discardableResult
    func drop(on binID: SortBin.ID) -> PlacementOutcome {
        let outcome = session.place(on: binID)
        switch outcome {
        case .correct:
            readRevealedFact()
        case .tryAgain:
            wrongDrops[binID, default: 0] += 1
            narrator.say("Hmm, try again!")
        case .ignored:
            break
        }
        return outcome
    }

    func readRevealedFact() {
        guard let item = revealedItem, let bin = stop.bin(id: item.binID) else { return }
        narrator.say("\(item.name). \(bin.title)! \(item.fact)")
    }

    func next() {
        session.advance()
        guard session.isFinished else {
            narrator.stop()
            return
        }
        let result = completeStop.execute(session)
        phase = .finished(result)
        narrator.say("Well done! You learned: \(stop.bigIdea.headline)")
    }

    func playAgain() {
        session = SortSession(stop: stop)
        wrongDrops = [:]
        phase = .playing
        askQuestion()
    }

    func leave() {
        narrator.stop()
    }
}
