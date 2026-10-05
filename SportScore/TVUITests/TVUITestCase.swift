import XCTest

/// Base class for Apple TV UI tests. Everything is driven with the Siri Remote, like a
/// real user: tests move focus with the arrows and assert what is focused, which is what
/// breaks on tvOS when a pop-up or column can't be reached.
class TVUITestCase: XCTestCase {
    var app: XCUIApplication!
    let remote = XCUIRemote.shared

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["ScoreCap"].waitForExistence(timeout: 10), "Home screen did not appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Focus

    /// The element that currently has focus.
    var focused: XCUIElement {
        app.descendants(matching: .any).element(matching: NSPredicate(format: "hasFocus == true"))
    }

    /// Label (or placeholder/identifier, for text fields and icons) of the focused element,
    /// or "" when nothing is focused.
    var focusedLabel: String {
        let element = focused
        guard element.exists else { return "" }
        return [element.label, element.placeholderValue ?? "", element.identifier]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    func focusedLabelContains(_ text: String) -> Bool {
        focusedLabel.localizedCaseInsensitiveContains(text)
    }

    /// Waits until the focused element's label contains `text`.
    @discardableResult
    func waitForFocus(_ text: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if focusedLabelContains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        attachScreenshot("focus-\(text)")
        XCTFail("Expected focus on “\(text)”, but focus is on “\(focusedLabel)”", file: file, line: line)
        return false
    }

    /// Presses `direction` until the focused element's label contains `text`.
    @discardableResult
    func moveFocus(
        to text: String,
        pressing direction: XCUIRemote.Button,
        maxPresses: Int = 25,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        for _ in 0...maxPresses {
            if focusedLabelContains(text) { return true }
            remote.press(direction)
            settle()
        }
        if focusedLabelContains(text) { return true }
        XCTFail("Could not reach “\(text)” by pressing \(direction); focus stuck on “\(focusedLabel)”", file: file, line: line)
        return false
    }

    /// Tries each direction in turn (useful when the exact layout varies).
    @discardableResult
    func reach(_ text: String, via directions: [XCUIRemote.Button], file: StaticString = #filePath, line: UInt = #line) -> Bool {
        for direction in directions {
            var stuck = 0
            for _ in 0..<40 {
                if focusedLabelContains(text) { return true }
                let before = focusedLabel
                remote.press(direction)
                settle()
                // Scrolling can delay the focus change; give up on a direction only after two dead presses.
                stuck = focusedLabel == before ? stuck + 1 : 0
                if stuck >= 2 { break }
            }
        }
        if !focusedLabelContains(text) { attachScreenshot("stuck-\(text)") }
        if focusedLabelContains(text) { return true }
        XCTFail("Could not reach “\(text)”; focus stuck on “\(focusedLabel)”", file: file, line: line)
        return false
    }

    func select() {
        remote.press(.select)
        settle(0.8)
    }

    func menu() {
        remote.press(.menu)
        settle(0.8)
    }

    func settle(_ seconds: TimeInterval = 0.35) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - Navigation

    /// Moves to a tab in the top tab bar.
    func openTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        // Up from content reaches the tab bar; Menu also returns there from a tab's root.
        for _ in 0..<12 where !app.tabBars.buttons[name].hasFocus && !tabBarFocused {
            remote.press(.up)
            settle()
        }
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "No “\(name)” tab", file: file, line: line)
        for direction in [XCUIRemote.Button.right, .left] {
            for _ in 0..<6 where !tab.hasFocus {
                remote.press(direction)
                settle()
            }
        }
        XCTAssertTrue(tab.hasFocus, "Could not focus the “\(name)” tab", file: file, line: line)
        remote.press(.down)
        settle(1)
    }

    private var tabBarFocused: Bool {
        app.tabBars.buttons.element(matching: NSPredicate(format: "hasFocus == true")).exists
    }

    func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? XCUIScreen.main.screenshot().pngRepresentation
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func dumpTree(_ name: String = #function) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("=== TREE \(name) ===\n\(app.debugDescription)")
        print("=== FOCUSED: \(focusedLabel)")
    }
}
