//
//  SortSessionTests.swift
//  TrailDomainTests
//

import XCTest
@testable import TrailDomain

final class SortSessionTests: XCTestCase {

    func testCorrectDropWaitsForAdvanceThenMovesOn() {
        var session = Fixtures.session()
        let duck = session.current!

        XCTAssertEqual(session.place(on: "float"), .correct(duck))
        XCTAssertTrue(session.awaitingNext)
        XCTAssertEqual(session.current, duck, "item stays current while its fact is shown")
        XCTAssertEqual(session.placedItems(in: "float"), [duck])

        session.advance()
        XCTAssertEqual(session.current?.id, "rock")
        XCTAssertEqual(session.progress, 0.5)
    }

    func testWrongDropCountsMistakeAndKeepsItem() {
        var session = Fixtures.session()
        let duck = session.current!

        XCTAssertEqual(session.place(on: "sink"), .tryAgain(duck))
        XCTAssertEqual(session.mistakes, 1)
        XCTAssertEqual(session.current, duck)
        XCTAssertFalse(session.awaitingNext)
    }

    func testDropsAreIgnoredWhileFactIsShown() {
        var session = Fixtures.session()
        _ = session.place(on: "float")

        XCTAssertEqual(session.place(on: "sink"), .ignored)
        XCTAssertEqual(session.mistakes, 0)
    }

    func testFinishesAfterLastItem() {
        var session = Fixtures.session()
        _ = session.place(on: "float"); session.advance()
        XCTAssertEqual(session.remaining, 0)
        _ = session.place(on: "sink"); session.advance()

        XCTAssertTrue(session.isFinished)
        XCTAssertNil(session.current)
        XCTAssertEqual(session.place(on: "sink"), .ignored)
        XCTAssertEqual(session.progress, 1)
    }

    func testAdvanceWithoutCorrectDropDoesNothing() {
        var session = Fixtures.session()
        session.advance()
        XCTAssertEqual(session.position, 0)
    }
}
