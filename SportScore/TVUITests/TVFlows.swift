import XCTest

/// Multi-step journeys shared by several test classes.
extension TVUITestCase {
    /// From launch (focus on the tab bar) to the first tile of the home screen.
    func focusFirstHomeTile(file: StaticString = #filePath, line: UInt = #line) {
        remote.press(.down)
        settle()
        waitForFocus("Create Custom Game", file: file, line: line)
    }

    /// Types into the focused text field with the tvOS keyboard and returns to the form.
    func typeInFocusedField(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        select()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard did not open", file: file, line: line)
        app.typeText(text)
        // Menu closes the full-screen keyboard and keeps the text.
        menu()
    }

    /// Opens a home game or sport from the Play tab by moving through the grid.
    func openGame(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        focusFirstHomeTile(file: file, line: line)
        reach(name, via: [.down, .right], file: file, line: line)
        select()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5), "Setup screen for \(name) did not open", file: file, line: line)
    }

    /// On a setup screen: adds new players through the alert and starts the game.
    func addPlayersAndStart(_ names: [String], file: StaticString = #filePath, line: UInt = #line) {
        for name in names {
            reach("Add new player", via: [.right, .down], file: file, line: line)
            select()
            XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "New Player alert did not appear", file: file, line: line)
            waitForFocus("Name", file: file, line: line)
            typeInFocusedField(name, file: file, line: line)
            reach("Add", via: [.down, .right], file: file, line: line)
            select()
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.waitForExistence(timeout: 5),
                          "Player \(name) was not added", file: file, line: line)
        }
        reach("Start", via: [.left, .down], file: file, line: line)
        select()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Undo'")).firstMatch.waitForExistence(timeout: 8)
                      || app.buttons["Undo"].waitForExistence(timeout: 2),
                      "Scoreboard did not open", file: file, line: line)
        settle(1)
    }

    /// Holds Select to open the context menu of the focused item.
    func longPressSelect() {
        remote.press(.select, forDuration: 1.6)
        settle(1)
    }

    /// Context menus and `Menu`s are drawn by tvOS outside the app, so their focus can't be
    /// read; the first item is focused when one opens. Picks the item at `index` from the top.
    func chooseMenuItem(_ index: Int) {
        for _ in 0..<index {
            remote.press(.down)
            settle()
        }
        select()
    }

    /// Moves to "End game", the right-most header button. tvOS doesn't report focus on a `Menu`
    /// button, so this presses up into the header and right to its end.
    func focusEndGame() {
        for _ in 0..<4 { remote.press(.up); settle() }
        for _ in 0..<3 { remote.press(.right); settle() }
        attachScreenshot("end-game-focused")
    }

    /// On the scoreboard: End game → the first option (a player wins).
    func endGameFromMenu(file: StaticString = #filePath, line: UInt = #line) {
        focusEndGame()
        select()
        chooseMenuItem(0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'wins!'")).firstMatch.waitForExistence(timeout: 5),
                      "Game over overlay did not appear", file: file, line: line)
    }
}
