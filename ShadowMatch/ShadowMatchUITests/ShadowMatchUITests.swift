//
//  ShadowMatchUITests.swift
//  ShadowMatchUITests
//
//  `-uiTesting` starts from a fresh install state and skips the tutorial
//  (add `-showTutorial` to see it) and the parental gate, signed out
//  (`-signedIn` fakes a Sign in with Apple account).
//

import XCTest

final class ShadowMatchUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        return app
    }

    /// Drags the current picture onto its shadow; returns the matched name.
    @discardableResult
    private func matchCurrent(in app: XCUIApplication) -> String {
        let current = app.images["shadow.current"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        let name = current.label.lowercased()
        let target = app.descendants(matching: .any)["shadow.target.\(name)"]
        XCTAssertTrue(target.exists, "missing shadow for \(name)")
        current.press(forDuration: 0.2, thenDragTo: target)
        return name
    }

    /// First launch: the tutorial's practice step needs a real match before "Start the journey!".
    func testTutorialPractice() throws {
        let app = launch(["-showTutorial"])

        app.buttons["tutorial.next"].tap()
        app.buttons["tutorial.next"].tap()

        let fox = app.images["tutorial.fox"]
        XCTAssertTrue(fox.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tutorial.start"].exists)
        fox.press(forDuration: 0.2, thenDragTo: app.descendants(matching: .any)["tutorial.target.fox"])

        let start = app.buttons["tutorial.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()
        XCTAssertTrue(app.buttons["pack.animals"].waitForExistence(timeout: 3))
    }

    func testTutorialSkip() throws {
        let app = launch(["-showTutorial"])
        app.buttons["tutorial.skip"].tap()
        XCTAssertTrue(app.buttons["pack.animals"].waitForExistence(timeout: 3))
    }

    /// First visit to a stop shows the intro; "Maybe later" goes back to the journey without playing.
    func testIntroMaybeLater() throws {
        let app = launch()
        app.buttons["pack.animals"].tap()
        app.buttons["intro.later"].tap()
        XCTAssertTrue(app.buttons["pack.animals"].waitForExistence(timeout: 3))

        // Intro already seen → the second visit goes straight to the game.
        app.buttons["pack.animals"].tap()
        XCTAssertTrue(app.images["shadow.current"].waitForExistence(timeout: 5))
    }

    /// Free pack: intro → play → match the first picture.
    func testPlayFreePack() throws {
        let app = launch()
        app.buttons["pack.animals"].tap()
        app.buttons["intro.play"].tap()

        let name = matchCurrent(in: app)
        let next = app.images["shadow.current"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertNotEqual(next.label.lowercased(), name)
    }

    /// Finishing a pack walks the fox on and shows the "Next stop" toast.
    func testFinishingPackAdvancesJourney() throws {
        let app = launch(["-unlockAllPacks"])
        app.buttons["pack.animals"].tap()
        app.buttons["intro.play"].tap()

        for _ in 0..<10 {
            matchCurrent(in: app)
            sleep(2)
        }
        let home = app.buttons["Home"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()

        XCTAssertTrue(app.staticTexts["Next stop: Things That Go!"].waitForExistence(timeout: 4))
    }

    /// Paid pack: tapping it shows the buy page.
    func testLockedPackOpensPurchasePage() throws {
        let app = launch()
        app.buttons["pack.ocean"].tap()
        XCTAssertTrue(app.buttons["purchase.buy"].waitForExistence(timeout: 5))
    }

    /// Grown-ups hub: lists every pack and opens the buy page for a locked one.
    func testComplianceHubListsPacks() throws {
        let app = launch()
        app.buttons["home.grownups"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["hub.restore"].waitForExistence(timeout: 5))
        for id in ["animals", "vehicles", "food", "ocean"] {
            XCTAssertTrue(app.descendants(matching: .any)["hub.pack.\(id)"].exists, "missing hub row for \(id)")
        }
        app.descendants(matching: .any)["hub.pack.food"].tap()
        XCTAssertTrue(app.buttons["purchase.buy"].waitForExistence(timeout: 5))
    }

    /// Signed out: the hub's Account section offers Sign in with Apple.
    func testHubOffersSignInWithApple() throws {
        let app = launch()
        app.buttons["home.grownups"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["hub.signIn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["hub.deleteAccount"].exists)
    }

    /// Signed in (`-signedIn` fake account): Delete Account asks first, then signs out.
    func testDeleteAccount() throws {
        let app = launch(["-signedIn"])
        app.buttons["home.grownups"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["hub.profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sam Parent"].exists)

        app.descendants(matching: .any)["hub.deleteAccount"].tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["hub.signIn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["hub.profile"].exists)
    }
}
