//
//  StopCatalogTests.swift
//  TrailDataTests
//
//  Content guard-rails: a typo in a bin id would make an item impossible to place.
//

import XCTest
import TrailDomain
@testable import TrailData

final class StopCatalogTests: XCTestCase {

    func testStopIDsAreUnique() {
        let ids = StopCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryStopIsPlayable() {
        for stop in StopCatalog.all {
            XCTAssertGreaterThanOrEqual(stop.bins.count, 2, stop.id)
            XCTAssertLessThanOrEqual(stop.bins.count, 3, "\(stop.id): more than 3 bins don't fit on a phone")
            XCTAssertEqual(stop.items.count, 10, stop.id)

            let itemIDs = stop.items.map(\.id)
            XCTAssertEqual(Set(itemIDs).count, itemIDs.count, "\(stop.id): duplicate item id")

            for item in stop.items {
                XCTAssertNotNil(stop.bin(id: item.binID), "\(stop.id)/\(item.id): unknown bin \(item.binID)")
                XCTAssertFalse(item.fact.isEmpty, "\(stop.id)/\(item.id): missing fact")
            }
            for bin in stop.bins {
                XCTAssertTrue(stop.items.contains { $0.binID == bin.id }, "\(stop.id): bin \(bin.id) is never used")
                XCTAssertFalse(stop.items.contains { $0.emoji == bin.emoji }, "\(stop.id): item reuses bin emoji \(bin.emoji)")
            }
        }
    }
}

final class UserDefaultsRepositoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "LittlePhysicsTrailTests"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testProgressRoundTripAndReset() {
        let repo = UserDefaultsProgressRepository(defaults: defaults)
        repo.setBestStars(2, for: "float")
        repo.setTotalStars(7)
        repo.markIntroSeen(for: "float")

        XCTAssertEqual(repo.bestStars(for: "float"), 2)
        XCTAssertEqual(repo.totalStars(), 7)
        XCTAssertTrue(repo.hasSeenIntro(for: "float"))

        repo.reset()
        XCTAssertEqual(repo.bestStars(for: "float"), 0)
        XCTAssertEqual(repo.totalStars(), 0)
        XCTAssertFalse(repo.hasSeenIntro(for: "float"))
    }

    func testResetKeepsSettings() {
        let settings = UserDefaultsSettingsRepository(defaults: defaults)
        XCTAssertTrue(settings.readAloud, "read aloud defaults to on")
        settings.readAloud = false

        UserDefaultsProgressRepository(defaults: defaults).reset()
        XCTAssertFalse(settings.readAloud)
    }
}
