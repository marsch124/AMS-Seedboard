import XCTest

/// 0.3: pictures on a board. The sample board "Balcony makeover" (`-board balcony`) holds two pictures, two
/// sticky notes and an arrow; `-pickPicture` chooses the first picture, as pressing it does.
/// Every control is found by its identifier; every wait is for an element or a value. (Written, not run.)
final class PictureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testAChosenPictureShowsItsBarWithoutWordsOrColour() {
        let app = XCUIApplication()
        var arguments = ["-sampleData", "-board", "balcony", "-pickPicture"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif

        // The board holds two pictures.
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear")
        let counted = expectation(for: NSPredicate(format: "label CONTAINS '2 pictures' OR value CONTAINS '2 pictures'"), evaluatedWith: count)
        XCTAssertEqual(XCTWaiter().wait(for: [counted], timeout: 10), .completed, "count line was \(count.label)")

        // The Picture tool is in the tool row.
        XCTAssertTrue(element(app, "tool.picture").waitForExistence(timeout: 10), "tool.picture did not appear")

        // The chosen picture's bar: Duplicate and Remove, no Words, Colour or To do.
        XCTAssertTrue(element(app, "sel.copy").waitForExistence(timeout: 10), "the bar of a picture did not appear")
        XCTAssertTrue(element(app, "sel.remove").exists, "Remove is missing")
        XCTAssertFalse(element(app, "sel.words").exists, "a picture has no words")
        XCTAssertFalse(element(app, "sel.colour").exists, "a picture has no colour")
        XCTAssertFalse(element(app, "sel.todo").exists, "a picture has no to-do tick")
    }
}
