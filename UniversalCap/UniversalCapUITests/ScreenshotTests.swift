import XCTest

final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    // SIMULATOR_HOST_HOME lets us write directly to the Mac Desktop from inside the simulator
    private static let outputDir: URL = {
        let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? ""
        let dir = URL(fileURLWithPath: home).appendingPathComponent("Desktop/UniversalCap-Screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Enforce 1242 × 2688 — run on iPhone 11 Pro Max simulator only
        let probe = XCUIScreen.main.screenshot()
        if let (w, h) = Self.pngDimensions(probe.pngRepresentation) {
            guard w == 1242 && h == 2688 else {
                throw XCTSkip("Run on iPhone 11 Pro Max for 1242×2688 screenshots (current: \(w)×\(h))")
            }
        }

        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()
        // Let the UI settle after launch
        Thread.sleep(forTimeInterval: 1.0)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Home screen states

    func test01_HomeAll() {
        snap("01-home-all")
    }

    func test02_HomeTasks() {
        app.buttons["Tasks"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        snap("02-home-tasks")
    }

    func test03_HomeExpenses() {
        app.buttons["Expenses"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        snap("03-home-expenses")
    }

    func test04_HomeThoughts() {
        app.buttons["Thoughts"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        snap("04-home-thoughts")
    }

    // MARK: - Paywall

    func test05_Paywall() {
        let proButton = app.buttons["Pro"]
        XCTAssertTrue(proButton.waitForExistence(timeout: 5), "Pro button not found — StoreKit may have resolved isPro=true")
        proButton.tap()
        Thread.sleep(forTimeInterval: 0.8)
        snap("05-paywall")
    }

    // MARK: - Onboarding (separate launch with --show-onboarding)

    func test06_Onboarding() {
        // Relaunch with --show-onboarding so the app shows OnboardingView directly.
        // In-memory store is used automatically for this flag — no CloudKit, no crash.
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--show-onboarding"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.0)

        // Page 1 — Welcome
        snap("06-onboarding-welcome")
        tapContinue()

        // Page 2 — Thoughts
        snap("07-onboarding-thoughts")
        tapContinue()

        // Page 3 — Expenses
        snap("08-onboarding-expenses")
        tapContinue()

        // Page 4 — Tasks
        snap("09-onboarding-tasks")
        tapContinue()

        // Page 5 — Get Started
        snap("10-onboarding-get-started")
    }

    // MARK: - Helpers

    private func tapContinue() {
        let btn = app.buttons["Continue"]
        XCTAssertTrue(btn.waitForExistence(timeout: 4), "Continue button not found on current onboarding page")
        btn.tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    // Reads width/height from the PNG IHDR chunk (bytes 16–23), no image framework needed.
    private static func pngDimensions(_ data: Data) -> (Int, Int)? {
        guard data.count >= 24 else { return nil }
        let w = Int(data[16]) << 24 | Int(data[17]) << 16 | Int(data[18]) << 8 | Int(data[19])
        let h = Int(data[20]) << 24 | Int(data[21]) << 16 | Int(data[22]) << 8 | Int(data[23])
        return (w, h)
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let file = Self.outputDir.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: file)
        print("📸 Saved: \(file.path)")
    }
}
