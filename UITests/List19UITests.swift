import XCTest

/// 0.19, lane "list": the Recent card's Sort menu, the done bar and the row's swipe, found by identifiers only.
final class List19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testSortMenuAndSwipeShow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()
        XCTAssertTrue(element(app, "boards.list").waitForExistence(timeout: 15), "the list did not appear")
        // Folds are kept per device: open Recent first if an earlier run left it folded.
        let sort = element(app, "boards.sort")
        if !sort.waitForExistence(timeout: 5) { element(app, "boards.fold.recent").tap() }
        XCTAssertTrue(sort.waitForExistence(timeout: 5), "the Sort menu is missing on the Recent card")
        #if os(iOS)
        let row = element(app, "boards.row.Summer cabin")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the Summer cabin row is missing")
        row.swipeRight()
        XCTAssertTrue(element(app, "boards.swipePin.Summer cabin").waitForExistence(timeout: 5), "the Unpin button did not show")
        #endif
    }
}
