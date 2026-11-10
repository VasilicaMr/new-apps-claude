//
//  LittlePhysicsTrailUITests.swift
//  LittlePhysicsTrailUITests
//
//  Happy path through the first stop: trail → big idea → sort all 10 items (tapping bins)
//  → finish → back on the trail with the owl moved on. Plus the Full Journey lock.
//

import XCTest

final class LittlePhysicsTrailUITests: XCTestCase {

    /// Correct bin for each item name in the "Sink or Float" stop (order is shuffled per play).
    private let floatAnswers: [String: String] = [
        "Rubber duck": "float", "Rock": "sink", "Apple": "float", "Coin": "sink", "Leaf": "float",
        "Key": "sink", "Log": "float", "Beach ball": "float", "Spoon": "sink", "Big ship": "float",
    ]

    func testPlayFirstStop() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["journey.stop.float"].tap()
        XCTAssertTrue(app.buttons["intro.play"].waitForExistence(timeout: 3))
        app.buttons["intro.play"].tap()

        let item = app.otherElements["lesson.item"]
        for _ in 0..<floatAnswers.count {
            XCTAssertTrue(item.waitForExistence(timeout: 3))
            let bin = floatAnswers[item.label] ?? "float"
            app.buttons["lesson.bin.\(bin)"].tap()
            XCTAssertTrue(app.buttons["lesson.next"].waitForExistence(timeout: 3))
            app.buttons["lesson.next"].tap()
        }

        XCTAssertTrue(app.buttons["lesson.home"].waitForExistence(timeout: 3))
        app.buttons["lesson.home"].tap()

        XCTAssertTrue(app.staticTexts["1 of 8 big ideas discovered"].waitForExistence(timeout: 3))
    }

    func testLockedStopOpensUnlockPage() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let light = app.buttons["journey.stop.light"]
        XCTAssertTrue(light.waitForExistence(timeout: 3))
        XCTAssertEqual(light.label, "Stop 4, Light & Shadow, locked")
        app.swipeUp()
        light.tap()

        // Parental gate opens itself under -uiTesting.
        XCTAssertTrue(app.staticTexts["unlock.title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["unlock.restore"].exists)
    }

    func testFullJourneyOpensEveryStop() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-unlockFullJourney"]
        app.launch()

        let matter = app.buttons["journey.stop.matter"]
        XCTAssertTrue(matter.waitForExistence(timeout: 3))
        XCTAssertEqual(matter.label, "Stop 8, Solid, Liquid, Gas, play")
    }
}
