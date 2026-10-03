import XCTest

/// End-to-end wizard test: Home → 3 seeded local video clips → Template →
/// Property info → Branding → Music → Preview → Export → render → done.
///
/// Clips are seeded from 3 bundled fixture videos (`ListingReel/Resources/
/// UITestFixtures`) via the `-UITestSeedClips` launch argument (see
/// `AppCoordinator.seedUITestClipsIfRequested`), so the test never depends on
/// the Photos picker or simulator photo library contents.
final class ExportFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFullWizardFlowThroughExport() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedClips", "-UITestSkipOnboarding"]
        app.launch()

        // Home → New Video
        let newVideoButton = app.buttons["home.newVideoButton"]
        XCTAssertTrue(newVideoButton.waitForExistence(timeout: 10), "Home screen never appeared")
        newVideoButton.tap()

        // Step 1 — Media (pre-seeded with 3 local clips)
        let mediaContinue = app.buttons["Continue"]
        XCTAssertTrue(mediaContinue.waitForExistence(timeout: 10), "Media step never appeared")
        XCTAssertTrue(mediaContinue.isEnabled, "Continue should be enabled once clips are seeded")
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

        // Step 4 — Branding (agent name required to enable Continue)
        let agentField = app.textFields["branding.agentNameField"]
        XCTAssertTrue(agentField.waitForExistence(timeout: 10), "Branding step never appeared")
        agentField.tap()
        agentField.typeText("Jane Realtor")
        let saveAndContinue = app.buttons["Save & Continue"]
        XCTAssertTrue(saveAndContinue.isEnabled, "Save & Continue should enable once agent name is filled")
        saveAndContinue.tap()

        // Step 5 — Music (keep default "No music")
        let musicContinue = app.buttons["Continue"]
        XCTAssertTrue(musicContinue.waitForExistence(timeout: 10), "Music step never appeared")
        musicContinue.tap()

        // Step 6 — Preview
        let exportNav = app.buttons["Export"]
        XCTAssertTrue(exportNav.waitForExistence(timeout: 10), "Preview step never appeared")
        exportNav.tap()

        // Step 7 — Export: render, then wait for either success or a surfaced failure.
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
            XCTFail("Export failed: \(messages.joined(separator: " | "))")
            return
        }

        XCTAssertEqual(outcome, .completed, "Export never reached a finished or failed state in time")
        XCTAssertTrue(resultsHeader.exists, "Expected the export results screen ('Done! 🎉')")
    }
}
