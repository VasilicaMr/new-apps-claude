import XCTest

/// Play tab: the game grid, context menus and the custom game editor.
final class TVHomeAndEditorTests: TVUITestCase {

    func testHomeGridIsReachableToTheLastSport() {
        focusFirstHomeTile()
        reach("Uno", via: [.down])
        reach("Arm Wrestling", via: [.down, .right])
        // And back up to the tab bar.
        reach("Play", via: [.up])
    }

    func testBuiltInGameContextMenuTakesFocus() {
        focusFirstHomeTile()
        reach("Uno", via: [.down])
        longPressSelect()
        chooseMenuItem(0) // Customize Rules…
        XCTAssertTrue(app.staticTexts["New Custom Game"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "Uno")
    }

    /// The reported bug: the Save buttons at the bottom of the editor couldn't be reached.
    func testCustomGameEditorEveryControlIsReachable() {
        focusFirstHomeTile()
        select()
        XCTAssertTrue(app.staticTexts["New Custom Game"].waitForExistence(timeout: 5))
        waitForFocus("Game name")

        typeInFocusedField("Quiz Night")
        waitForFocus("Game name")

        // Bottom of the form ("Play to", showing its value), then across to the buttons and back.
        reach("No limit", via: [.down])
        reach("Save & Play", via: [.left])
        remote.press(.down)
        settle()
        XCTAssertTrue(focusedLabel.hasPrefix("Save") && !focusedLabelContains("Play"),
                      "Down from Save & Play should reach Save, focus is on “\(focusedLabel)”")
        remote.press(.right)
        settle()
        XCTAssertFalse(focusedLabelContains("Save") || focusedLabel.isEmpty,
                       "Right from Save should return to the form, focus is on “\(focusedLabel)”")

        // From the top of the form the buttons must be reachable too.
        reach("Game name", via: [.up])
        reach("Save", via: [.left])
    }

    func testCustomGamePickerChangesRules() {
        focusFirstHomeTile()
        select()
        waitForFocus("Game name")
        // The "Winner" row shows its value and opens a tvOS menu (Highest, Lowest, Count down).
        reach("Highest score wins", via: [.down])
        select()
        attachScreenshot("winner-menu")
        chooseMenuItem(2)
        XCTAssertTrue(app.staticTexts["New Custom Game"].waitForExistence(timeout: 5), "Did not return to the editor")
        // Count-down games get a start score (501) instead of a target.
        reach("501", via: [.down])
    }

    func testSaveEditAndDeleteCustomGame() {
        focusFirstHomeTile()
        select()
        waitForFocus("Game name")
        typeInFocusedField("Family Quiz")
        reach("Save", via: [.left, .down])
        // Land on plain "Save" rather than "Save & Play".
        if focusedLabelContains("Save & Play") { remote.press(.down); settle() }
        select()

        // Back on the home screen with the new tile.
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Family Quiz'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        reach("Family Quiz", via: [.right, .down])

        longPressSelect()
        chooseMenuItem(1) // Play, Edit, Delete
        XCTAssertTrue(app.staticTexts["Edit Game"].waitForExistence(timeout: 5))

        reach("Delete Game", via: [.left, .down])
        select()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Delete confirmation did not appear")
        waitForFocus("Cancel") // the alert takes focus on the safe choice
        reach("Delete", via: [.right, .left]) // alert buttons sit side by side
        select()
        XCTAssertTrue(app.staticTexts["ScoreCap"].waitForExistence(timeout: 5))
        XCTAssertFalse(tile.waitForExistence(timeout: 2), "Deleted game is still on the home screen")
    }
}
