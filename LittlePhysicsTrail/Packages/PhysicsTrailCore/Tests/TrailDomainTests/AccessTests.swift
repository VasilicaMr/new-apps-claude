//
//  AccessTests.swift
//  TrailDomainTests
//

import XCTest
@testable import TrailDomain

final class AccessTests: XCTestCase {
    private let fiveStops = FixedStopRepository(stops: (1...5).map { Fixtures.stop("s\($0)") })

    func testFirstThreeStopsAreFree() {
        let policy = AccessPolicy.standard
        XCTAssertEqual((0..<5).map { policy.isLocked(stopAt: $0, ownsFullJourney: false) },
                       [false, false, false, true, true])
        XCTAssertFalse((0..<5).contains { policy.isLocked(stopAt: $0, ownsFullJourney: true) })
    }

    func testJourneyMarksLockedStops() {
        let journey = LoadJourneyUseCase(stops: fiveStops, progress: InMemoryProgressRepository(),
                                         entitlements: FakePurchaseService()).execute()
        XCTAssertEqual(journey.stops.map(\.isLocked), [false, false, false, true, true])
        XCTAssertEqual(journey.lockedStops.map(\.id), ["s4", "s5"])
    }

    func testLockedStopIsNeverSuggested() {
        let progress = InMemoryProgressRepository()
        progress.best = ["s1": 3, "s2": 2, "s3": 1]
        let purchases = FakePurchaseService()
        let useCase = LoadJourneyUseCase(stops: fiveStops, progress: progress, entitlements: purchases)

        XCTAssertNil(useCase.execute().nextStopID, "free stops done → no nudge toward the paywall")

        purchases.ownsFullJourney = true
        XCTAssertEqual(useCase.execute().nextStopID, "s4")
        XCTAssertTrue(useCase.execute().lockedStops.isEmpty)
    }

    func testUnlockUseCase() async {
        let purchases = FakePurchaseService()
        let unlock = UnlockJourneyUseCase(purchases: purchases)

        purchases.nextOutcome = .pending
        let pending = await unlock.purchase()
        XCTAssertEqual(pending, .pending)
        XCTAssertFalse(unlock.isUnlocked)

        purchases.restoreOwns = true
        let restored = await unlock.restore()
        XCTAssertTrue(restored)
        XCTAssertTrue(unlock.isUnlocked)
    }
}
