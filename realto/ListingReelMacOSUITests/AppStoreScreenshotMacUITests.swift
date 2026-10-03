import XCTest

/// Drives the real create → export wizard (same seeded-clips path as the iOS
/// `AppStoreScreenshotUITests`/`ExportFlowUITests`) on the actual macOS app
/// and captures `.keepAlways` screenshot attachments at 3 marketing-worthy
/// screens, for use as macOS App Store Connect screenshots/previews.
///
/// This runs the *native* app on the Mac (no Simulator involved — macOS UI
/// tests always launch the real built app), so it isn't affected by this
/// machine's broken iOS Simulator test runner.
///
/// The app's window is sized for a phone-portrait wizard (~480×720,
/// `ListingReelApp.swift`'s `minWidth`/`minHeight`), not the 1280×800 (or
/// larger) canvas App Store Connect requires — so raw attachments here are
/// meant to be composited onto a branded 1280×800 canvas afterward, not
/// uploaded as-is. Run `Scripts/generate-appstore-screenshots-macos.sh`
/// end-to-end (test → extract → composite via
/// `Scripts/compose-appstore-screenshot.py`).
final class AppStoreScreenshotMacUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMacScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedClips", "-UITestSkipOnboarding"]
        app.launch()

        // 01 — Home: the zero-friction empty state, first thing every user sees.
        let newVideoButton = app.buttons["home.newVideoButton"]
        XCTAssertTrue(newVideoButton.waitForExistence(timeout: 10), "Home screen never appeared")
        attachScreenshot(named: "01_Home", app: app)
        newVideoButton.tap()

        // Step 1 — Media (pre-seeded with 3 local clips, no Photos picker needed)
        let mediaContinue = app.buttons["Continue"]
        XCTAssertTrue(mediaContinue.waitForExistence(timeout: 10), "Media step never appeared")
        mediaContinue.tap()

        // Step 2 — Template (a default template is already selected)
        let templateContinue = app.buttons["Continue"]
        XCTAssertTrue(templateContinue.waitForExistence(timeout: 10), "Template step never appeared")
        templateContinue.tap()

        // Step 3 — Property info
        let addressField = app.textFields["propertyInfo.addressField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 10), "Property info step never appeared")
        addressField.tap()
        addressField.typeText("123 Maple Ave, Springfield")
        app.buttons["Continue"].tap()

        // Step 4 — Branding
        let agentField = app.textFields["branding.agentNameField"]
        XCTAssertTrue(agentField.waitForExistence(timeout: 10), "Branding step never appeared")
        agentField.tap()
        agentField.typeText("Jane Realtor")
        let saveAndContinue = app.buttons["Save & Continue"]
        XCTAssertTrue(saveAndContinue.isEnabled, "Save & Continue should enable once agent name is filled")
        saveAndContinue.tap()

        // Step 5 — Music (keep default)
        let musicContinue = app.buttons["Continue"]
        XCTAssertTrue(musicContinue.waitForExistence(timeout: 10), "Music step never appeared")
        musicContinue.tap()

        // 02 — Preview: the real composition (branding + property card + clips).
        let exportNav = app.buttons["Export"]
        XCTAssertTrue(exportNav.waitForExistence(timeout: 10), "Preview step never appeared")
        attachScreenshot(named: "02_Preview", app: app)
        exportNav.tap()

        // Step 7 — Export: render, then wait for success.
        let renderButton = app.buttons["export.renderButton"]
        XCTAssertTrue(renderButton.waitForExistence(timeout: 10), "Export step never appeared")
        renderButton.tap()

        let resultsHeader = app.staticTexts["Done! 🎉"]
        let failureHeader = app.staticTexts["Export failed"]
        let outcome = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"), object: resultsHeader),
                  XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"), object: failureHeader)],
            timeout: 120)

        if failureHeader.exists {
            let messages = app.staticTexts.allElementsBoundByIndex.map(\.label)
            XCTFail("Export failed, can't capture success screenshot: \(messages.joined(separator: " | "))")
            return
        }

        XCTAssertEqual(outcome, .completed, "Export never reached a finished or failed state in time")
        XCTAssertTrue(resultsHeader.exists, "Expected the export results screen ('Done! 🎉')")

        // 03 — Export results: proves the render actually finishes successfully.
        attachScreenshot(named: "03_ExportDone", app: app)
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
