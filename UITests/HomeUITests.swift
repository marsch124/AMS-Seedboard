import XCTest

/// The home page with its cards, and the search over the boards list (0.2).
/// Every control is found by its identifier; every wait is for an element.
final class HomeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with made-up boards. `-sampleData` always goes last.
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = extra
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func press(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        target.tap()
    }

    private func waitUntilGone(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, id))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "\(id) is still there", file: file, line: line)
    }

    /// The home page shows the starters and the boards as cards; the search field finds a board by a word
    /// that is written on it; the home page's New board button opens the choice of starters.
    func testHomeShowsCardsAndSearchFindsABoardByAWordOnIt() {
        let app = launch()
        let search = element(app, "boards.search")
        XCTAssertTrue(search.waitForExistence(timeout: 15), "the search field did not appear")
        XCTAssertTrue(element(app, "boards.row.Trip to Spain").waitForExistence(timeout: 10))

        // Mac and iPad: the home page is beside the list. On the iPhone the list itself is the home.
        let hasHome = element(app, "board.none").waitForExistence(timeout: 3)
        if hasHome {
            XCTAssertTrue(element(app, "home.starter.mindMap").waitForExistence(timeout: 10), "no starter cards")
            XCTAssertTrue(element(app, "home.starter.blank").exists)
            XCTAssertTrue(element(app, "home.starter.flow").exists)
            XCTAssertTrue(element(app, "home.board.Summer cabin").exists, "no board cards")
        }

        // "timber" is in no board's name: it is written on a sticky note of "Summer cabin".
        search.tap()
        search.typeText("timber")
        waitUntilGone(app, "boards.row.Trip to Spain")
        XCTAssertTrue(element(app, "boards.row.Summer cabin").exists, "the board with the word was not found")
        if hasHome {
            XCTAssertTrue(element(app, "home.board.Summer cabin").exists)
            XCTAssertFalse(element(app, "home.board.Trip to Spain").exists)
        }

        // Words that are on no board: one plain line.
        search.typeText(" zzzz")
        XCTAssertTrue(element(app, "boards.noMatch").waitForExistence(timeout: 10))
        press(app, "boards.searchClear")
        XCTAssertTrue(element(app, "boards.row.Trip to Spain").waitForExistence(timeout: 10), "clearing did not bring the boards back")

        // The home page's own New board button opens the same choice of starters as the list's.
        if hasHome {
            press(app, "empty.newBoard")
            XCTAssertTrue(element(app, "starter.mindMap").waitForExistence(timeout: 10), "the starters did not open")
            press(app, "starter.flow")
            XCTAssertTrue(element(app, "board.canvas").waitForExistence(timeout: 15), "the new board did not open")
        }
    }
}
