import XCTest

/// Walks through every screen and pop-up and captures a screenshot of each, for checking the
/// layout, button shapes and light/dark appearance. Screenshots are attached to the test
/// result; set `TEST_RUNNER_SCREENSHOT_DIR` to also write them as PNG files.
final class TVScreenshotTests: TVUITestCase {

    func testCaptureAllScreens() {
        shot("01-home")
        focusFirstHomeTile()
        shot("02-home-focused-tile")

        select()
        _ = app.staticTexts["New Custom Game"].waitForExistence(timeout: 5)
        typeInFocusedField("Quiz Night")
        reach("Save & Play", via: [.left])
        shot("03-custom-game-editor")
        menu()

        reach("Uno", via: [.down])
        longPressSelect()
        shot("04-context-menu")
        menu()
        select()
        _ = app.buttons["Start"].waitForExistence(timeout: 5)
        shot("05-setup-empty")
        reach("Add new player", via: [.right, .down])
        select()
        shot("06-new-player-alert")
        menu()
        addPlayersAndStart(["Ann", "Ben", "Cleo"])
        shot("07-scoreboard-turns")
        select() // +1 for Ann
        settle(0.5)
        shot("08-score-flash")

        reach("Enter points", via: [.down])
        select()
        shot("09-number-pad")
        menu()

        focusEndGame()
        select()
        shot("10-end-game-menu")
        chooseMenuItem(0)
        settle(1)
        shot("11-game-over")
        reach("View Results", via: [.up])
        select()
        _ = app.staticTexts["Match Info"].waitForExistence(timeout: 5)
        shot("12-results")

        menu()
        focusFirstHomeTile()
        reach("Monopoly", via: [.down, .right])
        select()
        _ = app.buttons["Start"].waitForExistence(timeout: 5)
        reach("Ann", via: [.right])
        select()
        reach("Ben", via: [.down])
        select()
        reach("Start", via: [.left, .down])
        shot("13-setup-players-selected")
        select()
        settle(1.5)
        select()
        settle(0.5)
        shot("14-scoreboard-tally")
        menu()
        settle(1)
        shot("15-home-continue-banner")

        openTab("Plans")
        shot("16-plans-empty")
        select()
        settle(1)
        shot("17-plan-editor")
        typeInFocusedField("Game Night")
        reach("Save", via: [.down])
        select()
        settle(1)
        shot("18-plans")

        openTab("History")
        shot("19-history")
        openTab("Players")
        shot("20-players")
        openTab("Stats")
        shot("21-stats")
        reach("Player leaderboard", via: [.down, .left])
        select()
        settle(1.5)
        shot("22-paywall")
    }

    private func shot(_ name: String) {
        settle(0.6)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
