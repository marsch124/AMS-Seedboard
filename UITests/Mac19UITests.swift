import XCTest

/// 0.19: the "+" on the tool bar holds a menu of Note, Idea, Shape, Text. Found by identifiers only.
final class Mac19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testAddToolIsOnTheToolBar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()
        let board = app.descendants(matching: .any).matching(identifier: "boards.row.Summer cabin").firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 15), "the board list did not appear")
        board.tap()
        let add = app.descendants(matching: .any).matching(identifier: "tool.add").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "the + tool is missing")
    }
}
