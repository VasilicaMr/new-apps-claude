import XCTest

final class PaywallScreenshotTests: XCTestCase {
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

    func testPaywallTopScreenshot() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        attach(app.screenshot(), named: "Paywall-Top")
    }

    func testPaywallScrolledScreenshot() throws {
        XCTAssertTrue(app.navigationBars["ScoreCap Premium"].waitForExistence(timeout: 5))
        app.swipeUp()
        attach(app.screenshot(), named: "Paywall-Scrolled")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"]
            ?? ProcessInfo.processInfo.environment["HOME"]
            ?? NSHomeDirectory()
        let desktop = URL(fileURLWithPath: home)
            .appendingPathComponent("Desktop")
            .appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: desktop)
        } catch {
            XCTFail("Screenshot write failed (\(desktop.path)): \(error)")
        }
    }
}
