import XCTest

/// 0.5, pick 13: the page "Door to a board…" — its heading, "New board", the search field, the other boards
/// (never the open one), Cancel; a board pressed becomes a door on the open board and the page closes.
/// Every control is found by its identifier.
final class DoorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTheDoorPageListsTheOtherBoardsAndABoardPressedBecomesADoor() {
        let app = XCUIApplication()
        var arguments = ["-board", "cabin", "-doorPage", "-sampleData"]
        #if os(macOS)
        arguments = ["-ApplePersistenceIgnoreState", "YES"] + arguments
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif

        XCTAssertTrue(element(app, "door.page").waitForExistence(timeout: 20), "the page Door to a board did not open")
        for id in ["door.heading", "door.new", "door.search", "door.cancel"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 10), "\(id) is missing")
        }
        // The other boards are listed; the open board is not (a board has no door to itself).
        let row = element(app, "door.row.Arrow looks")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no row for the board Arrow looks")
        XCTAssertFalse(element(app, "door.row.Summer cabin").exists, "the open board must not be offered")

        row.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "door.page"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "pressing a board did not close the page")

        // The board now holds one door (the iPhone gives the count line as the label, the Mac as the value).
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear")
        let door = expectation(for: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "1 door", "1 door"), evaluatedWith: count)
        XCTAssertEqual(XCTWaiter().wait(for: [door], timeout: 10), .completed, "the board's count line does not say 1 door")
    }
}
