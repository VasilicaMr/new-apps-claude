import XCTest

/// Setup screen, scoreboard and every pop-up on it, results.
final class TVGameFlowTests: TVUITestCase {

    func testSetupScreenAddPlayerAlertAndStart() {
        openGame("Uno")
        addPlayersAndStart(["Ann", "Ben"])
        // Turn-based home game: the first score button is focused when the scoreboard opens.
        waitForFocus("+1")
    }

    func testNumberPadSheetTakesFocusAndScores() {
        openGame("Uno")
        addPlayersAndStart(["Ann", "Ben"])
        reach("Enter points", via: [.down])
        select()
        XCTAssertTrue(app.staticTexts["Points to add"].waitForExistence(timeout: 5), "Number pad did not open")
        // The pad takes focus, starting on 1.
        waitForFocus("1")
        XCTAssertEqual(focusedLabel, "1")
        remote.press(.down); settle()
        XCTAssertEqual(focusedLabel, "4")
        select()
        remote.press(.up); settle()
        remote.press(.right); settle()
        XCTAssertEqual(focusedLabel, "2")
        select()
        reach("+42", via: [.down])
        select()
        XCTAssertFalse(app.staticTexts["Points to add"].waitForExistence(timeout: 2), "Number pad did not close")
        XCTAssertTrue(app.staticTexts["42"].waitForExistence(timeout: 5), "Score was not added")
        XCTAssertFalse(focusedLabel.isEmpty, "Nothing focused after closing the number pad")
    }

    func testEndGameMenuAndGameOverOverlayTakeFocus() {
        openGame("Uno")
        addPlayersAndStart(["Ann", "Ben"])
        endGameFromMenu()
        waitForFocus("View Results")
        // Focus must stay inside the overlay.
        for direction in [XCUIRemote.Button.up, .left, .right, .up] {
            remote.press(direction)
            settle()
            XCTAssertTrue(["View Results", "Undo last", "See scores", "Done"].contains { focusedLabelContains($0) },
                          "Focus escaped the game over overlay to “\(focusedLabel)”")
        }
        reach("View Results", via: [.up])
        select()
        XCTAssertTrue(app.staticTexts["Match Info"].waitForExistence(timeout: 5), "Results did not open")
    }

    func testSeeScoresThenShowResultAgain() {
        openGame("Uno")
        addPlayersAndStart(["Ann", "Ben"])
        endGameFromMenu()
        waitForFocus("View Results")
        reach("See scores", via: [.down, .right])
        select()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'wins!'")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(focusedLabel.isEmpty, "Nothing focused after closing the overlay")
        reach("Show result", via: [.up, .right])
        select()
        waitForFocus("View Results")
        reach("Done", via: [.down, .right])
        select()
        XCTAssertTrue(app.staticTexts["ScoreCap"].waitForExistence(timeout: 5) || app.buttons["Start"].exists)
    }

    func testTallyGameCardsContextMenuAndLeaving() {
        openGame("Monopoly")
        addPlayersAndStart(["Ann", "Ben"])
        waitForFocus("Ann")
        select()
        XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 5), "Clicking a player card did not score")

        longPressSelect()
        chooseMenuItem(1) // −1, Add points…, Undo
        XCTAssertTrue(app.staticTexts["Points for Ann"].waitForExistence(timeout: 5), "Number pad did not open from the context menu")
        waitForFocus("1")
        menu()
        XCTAssertFalse(app.staticTexts["Points for Ann"].waitForExistence(timeout: 2))
        XCTAssertFalse(focusedLabel.isEmpty, "Nothing focused after closing the number pad")

        // Menu leaves the scoreboard; the game can be continued from Home.
        menu()
        let banner = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Continue Monopoly'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Continue banner missing after leaving the game")
    }

    func testSportVariantPickerAndScoreboard() {
        openGame("Darts")
        XCTAssertTrue(app.staticTexts["Variant"].exists, "Variant picker has no label")
        // The variant menu has focus when the screen opens (tvOS doesn't report focus on a menu picker).
        XCTAssertTrue(focusedLabel.isEmpty, "Expected the variant menu to be focused, focus is on “\(focusedLabel)”")
        select()
        settle(1)
        menu() // close the variant menu
        XCTAssertTrue(app.buttons["Start"].exists, "Closing the variant menu left the setup screen")
        addPlayersAndStart(["Ann", "Ben"])
        XCTAssertFalse(focusedLabel.isEmpty, "Darts scoreboard opened with nothing focused")
    }
}
