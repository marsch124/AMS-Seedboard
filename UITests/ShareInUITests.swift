import XCTest

/// 0.5, pick 24: the page of Share › Seedboard. A share page cannot be opened by a screen test where it lives
/// (another app's Share button), so the app shows the very same page with made-up content (`-sharePage`).
/// Every control is found by its identifier; every wait is for an element.
final class ShareInUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// "New board" is first and picked; a board can be picked instead; Send is there; Cancel closes the page.
    func testTheSharePageOffersNewBoardFirstThenTheBoards() {
        let app = XCUIApplication()
        var arguments = ["-sharePage"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()

        let newBoard = element(app, "shareIn.newBoard")
        XCTAssertTrue(newBoard.waitForExistence(timeout: 20), "the share page did not appear")
        XCTAssertTrue(newBoard.isSelected, "New board is picked when the page opens")
        XCTAssertEqual(element(app, "shareIn.what").label, "A link and 2 pictures")
        XCTAssertTrue(element(app, "shareIn.later").exists)
        XCTAssertTrue(element(app, "shareIn.send").isEnabled)

        // New board lies above every board.
        let cabin = element(app, "shareIn.board.Summer cabin")
        XCTAssertTrue(cabin.waitForExistence(timeout: 5), "the pinned board is not offered")
        XCTAssertLessThan(newBoard.frame.minY, cabin.frame.minY)
        // A board that places its own things is not offered.
        XCTAssertFalse(element(app, "shareIn.board.Build timeline").exists)

        cabin.tap()
        XCTAssertTrue(cabin.isSelected)
        XCTAssertFalse(newBoard.isSelected)

        element(app, "shareIn.cancel").tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "shareIn.newBoard"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "Cancel did not close the page")
    }
}
