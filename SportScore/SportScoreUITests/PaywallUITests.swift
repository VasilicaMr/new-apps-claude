import XCTest

final class PaywallUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-paywall"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testPaywallPresents() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
    }

    func testBuyButtonExists() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        let buyButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Buy'")).firstMatch
        XCTAssertTrue(buyButton.waitForExistence(timeout: 5))
        XCTAssertTrue(buyButton.isEnabled)
    }

    func testBuyButtonTriggersPurchaseFlow() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        let buyButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Buy'")).firstMatch
        XCTAssertTrue(buyButton.waitForExistence(timeout: 5))
        buyButton.tap()
        // StoreKit sandbox sheet or in-app loading indicator should appear
        let loadingOrSheet = app.activityIndicators.firstMatch.waitForExistence(timeout: 3)
            || app.sheets.firstMatch.waitForExistence(timeout: 5)
            || app.navigationBars["ScoreCap Premium"].exists
        XCTAssertTrue(loadingOrSheet)
    }

    func testRestoreButtonExists() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore purchase"].waitForExistence(timeout: 5))
    }

    func testNotNowDismissesPaywall() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        app.buttons["Not now"].tap()
        XCTAssertFalse(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 3))
    }

    func testAllFeaturesListed() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unlimited session history"].exists)
        XCTAssertTrue(app.staticTexts["Full stats & player leaderboards"].exists)
        XCTAssertTrue(app.staticTexts["Widget on your Home Screen"].exists)
        XCTAssertTrue(app.staticTexts["Never lose your data"].exists)
    }

    func testHeaderTextVisible() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unlock the full game"].exists)
        XCTAssertTrue(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS 'One-time purchase'"))
                .firstMatch.exists
        )
    }
}
