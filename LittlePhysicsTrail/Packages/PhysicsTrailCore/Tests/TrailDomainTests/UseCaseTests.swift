//
//  UseCaseTests.swift
//  TrailDomainTests
//

import XCTest
@testable import TrailDomain

final class UseCaseTests: XCTestCase {

    func testStarRating() {
        XCTAssertEqual(StarRating.stars(forMistakes: 0), 3)
        XCTAssertEqual(StarRating.stars(forMistakes: 1), 2)
        XCTAssertEqual(StarRating.stars(forMistakes: 2), 2)
        XCTAssertEqual(StarRating.stars(forMistakes: 3), 1)
        XCTAssertEqual(StarRating.stars(forMistakes: 40), 1)
    }

    func testJourneySuggestsFirstUnfinishedStop() {
        let progress = InMemoryProgressRepository()
        progress.best = ["a": 2]
        progress.total = 5
        let useCase = LoadJourneyUseCase(
            stops: FixedStopRepository(stops: [Fixtures.stop("a"), Fixtures.stop("b"), Fixtures.stop("c")]),
            progress: progress,
            entitlements: FakePurchaseService()
        )

        let journey = useCase.execute()

        XCTAssertEqual(journey.stops.map(\.bestStars), [2, 0, 0])
        XCTAssertEqual(journey.nextStopID, "b")
        XCTAssertEqual(journey.totalStars, 5)
        XCTAssertEqual(journey.completedCount, 1)
    }

    func testJourneyHasNoSuggestionWhenAllDone() {
        let progress = InMemoryProgressRepository()
        progress.best = ["a": 1]
        let journey = LoadJourneyUseCase(stops: FixedStopRepository(stops: [Fixtures.stop("a")]), progress: progress,
                                         entitlements: FakePurchaseService()).execute()
        XCTAssertNil(journey.nextStopID)
    }

    func testCompleteStopAddsStarsAndOnlyRaisesBest() {
        let progress = InMemoryProgressRepository()
        let useCase = CompleteStopUseCase(progress: progress)

        var perfect = Fixtures.session()
        _ = perfect.place(on: "float"); perfect.advance()
        _ = perfect.place(on: "sink"); perfect.advance()
        XCTAssertEqual(useCase.execute(perfect), StopResult(stars: 3, isNewBest: true, totalStars: 3))

        var sloppy = Fixtures.session()
        for _ in 0..<3 { _ = sloppy.place(on: "sink") }
        _ = sloppy.place(on: "float"); sloppy.advance()
        _ = sloppy.place(on: "sink"); sloppy.advance()
        XCTAssertEqual(useCase.execute(sloppy), StopResult(stars: 1, isNewBest: false, totalStars: 4))
        XCTAssertEqual(progress.best["float"], 3)
    }

    func testIntroShownOnlyOnFirstVisit() {
        let progress = InMemoryProgressRepository()
        let intro = StopIntroUseCase(progress: progress)
        let stop = Fixtures.stop()

        XCTAssertTrue(intro.shouldShow(stop))
        intro.markSeen(stop)
        XCTAssertFalse(intro.shouldShow(stop))
    }

    func testResetClearsProgress() {
        let progress = InMemoryProgressRepository()
        progress.best = ["a": 3]; progress.total = 3; progress.intros = ["a"]
        ResetProgressUseCase(progress: progress).execute()
        XCTAssertTrue(progress.best.isEmpty)
        XCTAssertEqual(progress.total, 0)
        XCTAssertTrue(progress.intros.isEmpty)
    }
}
