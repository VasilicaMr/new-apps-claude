import XCTest

/// Drives the real create → export wizard (same seeded-clips path as
/// `ExportFlowUITests`) and captures `.keepAlways` screenshot attachments at
/// four marketing-worthy screens, for use as App Store Connect screenshots.
///
/// These are UI tests, not unit tests — screenshotting requires a running
/// `XCUIApplication`, which only UI test targets have access to.
///
/// ## Producing screenshots for App Store Connect
///
/// Run each test method against the specific simulator whose screen size
/// matches the App Store Connect screenshot bucket you're filling:
///
/// - **6.5" Display** (`testCaptureIPhoneScreenshots`) → run on an
///   "iPhone 11 Pro Max" simulator (1242×2688 — the exact 6.5" device).
/// - **13" Display, iPad** (`testCaptureIPadScreenshot`) → run on an
///   "iPad Pro 13-inch (M4)" simulator (2064×2752 — the exact 13" device).
///
/// `Scripts/generate-appstore-screenshots.sh` automates both runs and
/// extracts the attachments as ready-to-upload PNGs into
/// `AppStoreAssets/Screenshots/`.
///
/// Note: this app is iPhone-only (`TARGETED_DEVICE_FAMILY: "1"` in
/// project.yml, spec §1.5 non-goals don't mention iPad). Run on an iPad
/// simulator, it launches in iPhone-compatibility mode (windowed/scaled),
/// not a native iPad layout — that's expected until the target adds iPad
/// support. The iPad screenshot below reflects exactly that compatibility
/// presentation.
final class AppStoreScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureIPhoneScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedClips"]
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

        // 02 — Template: shows the style picker (Classic / Bold / Minimal).
        let templateContinue = app.buttons["Continue"]
        XCTAssertTrue(templateContinue.waitForExistence(timeout: 10), "Template step never appeared")
        attachScreenshot(named: "02_Template", app: app)
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

        // 03 — Preview: the real composition (branding + property card + clips).
        let exportNav = app.buttons["Export"]
        XCTAssertTrue(exportNav.waitForExistence(timeout: 10), "Preview step never appeared")
        attachScreenshot(named: "03_Preview", app: app)
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

        // 04 — Export results: proves the render actually finishes successfully.
        attachScreenshot(named: "04_ExportDone", app: app)
    }

    func testCaptureIPadScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedClips"]
        app.launch()

        let newVideoButton = app.buttons["home.newVideoButton"]
        XCTAssertTrue(newVideoButton.waitForExistence(timeout: 10), "Home screen never appeared")
        newVideoButton.tap()

        let mediaContinue = app.buttons["Continue"]
        XCTAssertTrue(mediaContinue.waitForExistence(timeout: 10), "Media step never appeared")
        mediaContinue.tap()

        let templateContinue = app.buttons["Continue"]
        XCTAssertTrue(templateContinue.waitForExistence(timeout: 10), "Template step never appeared")
        templateContinue.tap()

        let addressField = app.textFields["propertyInfo.addressField"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 10), "Property info step never appeared")
        addressField.tap()
        addressField.typeText("123 Maple Ave, Springfield")
        app.buttons["Continue"].tap()

        let agentField = app.textFields["branding.agentNameField"]
        XCTAssertTrue(agentField.waitForExistence(timeout: 10), "Branding step never appeared")
        agentField.tap()
        agentField.typeText("Jane Realtor")
        app.buttons["Save & Continue"].tap()

        let musicContinue = app.buttons["Continue"]
        XCTAssertTrue(musicContinue.waitForExistence(timeout: 10), "Music step never appeared")
        musicContinue.tap()

        // Single iPad screenshot: the Preview screen — the most compelling
        // single shot of the app's core value (real composition + branding).
        let exportNav = app.buttons["Export"]
        XCTAssertTrue(exportNav.waitForExistence(timeout: 10), "Preview step never appeared")
        attachScreenshot(named: "01_Preview_iPad", app: app)
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
