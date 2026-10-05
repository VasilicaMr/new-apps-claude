import XCTest

/// Plans, History, Players and Stats tabs, with their sheets, alerts and context menus.
final class TVTabsTests: TVUITestCase {

    func testPlayersAddAlertAndDeleteMenu() {
        openTab("Players")
        waitForFocus("Add player")
        select()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        waitForFocus("Name")
        typeInFocusedField("Cleo")
        reach("Add", via: [.down, .right])
        select()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cleo'")).firstMatch.waitForExistence(timeout: 5))

        reach("Cleo", via: [.down])
        longPressSelect()
        chooseMenuItem(0) // Delete Cleo
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cleo'")).firstMatch.waitForExistence(timeout: 2))
    }

    func testPlansNewPlanSheetTakesFocus() {
        openTab("Plans")
        waitForFocus("New Plan")
        select()
        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 5) || app.staticTexts["New Plan"].waitForExistence(timeout: 2))
        waitForFocus("Plan name")
        typeInFocusedField("Game Night")
        reach("Save", via: [.down])
        select()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Game Night'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Plan was not saved")

        reach("Game Night", via: [.down])
        longPressSelect()
        chooseMenuItem(0) // Edit, Delete
        waitForFocus("Plan name")
        reach("Delete Plan", via: [.down])
        select()
        XCTAssertFalse(card.waitForExistence(timeout: 2), "Plan was not deleted")
        XCTAssertFalse(focusedLabel.isEmpty, "Nothing focused after the sheet closed")
    }

    func testHistoryRowOpensDetailAndContextMenu() {
        openGame("Uno")
        addPlayersAndStart(["Ann", "Ben"])
        menu() // leave the game; it stays in progress

        openTab("History")
        reach("Uno", via: [.down])
        select()
        XCTAssertTrue(app.staticTexts["Match Info"].waitForExistence(timeout: 5))
        waitForFocus("Resume game")
        menu()
        reach("Uno", via: [.down])
        longPressSelect()
        chooseMenuItem(0) // Delete
        XCTAssertTrue(app.staticTexts["No games yet"].waitForExistence(timeout: 5))
    }

    func testStatsLockedRowOpensPaywallWithFocus() {
        openGame("Uno")
        addPlayersAndStart(["Ann", "Ben"])
        endGameFromMenu()
        reach("Done", via: [.down, .right])
        select()

        openTab("Stats")
        reach("Player leaderboard", via: [.down, .left])
        select()
        XCTAssertTrue(app.staticTexts["Unlock the full game"].waitForExistence(timeout: 5), "Paywall did not open")
        XCTAssertTrue(["Buy", "Restore purchase", "Not now"].contains { focusedLabelContains($0) },
                      "Paywall did not take focus, focus is on “\(focusedLabel)”")
        reach("Not now", via: [.down])
        select()
        XCTAssertFalse(app.staticTexts["Unlock the full game"].waitForExistence(timeout: 2))
        // Across to the Sports list and back.
        reach("Uno", via: [.right])
        reach("Player leaderboard", via: [.left])
    }
}
