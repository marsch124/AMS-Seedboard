import XCTest

/// The iPhone's boards list (0.5, the owner's pick of 18 Nov 2026): the search field and the round "+" sit at
/// the BOTTOM of the list, under the thumb — below the boards, above the "Settings" line — and stay in reach
/// with the keyboard up. This test locks that place: do not move them without his yes.
/// Every control is found by its identifier; every wait is for an element.
final class ThumbUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testSearchAndPlusSitUnderTheThumbOnTheIPhone() throws {
        #if os(iOS)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "The thumb row is the iPhone's layout only.")
        let app = XCUIApplication()
        // 0.17: the cards open whatever this device folded before.
        app.launchArguments = ["-fold.list.pinned", "NO", "-fold.list.recent", "NO", "-sampleData"]
        app.launch()

        let search = element(app, "boards.search")
        let plus = element(app, "boards.new")
        let settings = element(app, "boards.settings")
        let firstRow = element(app, "boards.row.Summer cabin")
        XCTAssertTrue(search.waitForExistence(timeout: 15), "the search field did not appear")
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "the + did not appear")
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "the gear did not appear")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "the boards did not appear")

        // In the lower quarter of the screen. 0.17: the gear sits alone at the top right instead of a bottom line.
        let screen = app.windows.firstMatch.frame
        let lowerQuarter = screen.minY + screen.height * 0.75
        for (name, frame) in [("the search field", search.frame), ("the +", plus.frame)] {
            XCTAssertGreaterThanOrEqual(frame.minY, lowerQuarter, "\(name) is not in the lower quarter of the screen")
        }
        XCTAssertLessThan(settings.frame.maxY, screen.minY + screen.height * 0.2, "the gear is not at the top")
        XCTAssertGreaterThan(settings.frame.minX, screen.midX, "the gear is not at the right")
        // One row: the search field at the left, the "+" at its right, a full finger tall.
        XCTAssertLessThan(search.frame.maxX, plus.frame.minX, "the + is not at the right of the search field")
        XCTAssertGreaterThanOrEqual(plus.frame.height, 44, "the + is smaller than a finger")
        XCTAssertGreaterThanOrEqual(plus.frame.width, 44, "the + is smaller than a finger")

        // Below the boards: the first row ends above them, and no row that can be pressed starts below them.
        // (Rows further down the list wait under the row, out of sight, until the list is slid up.)
        XCTAssertLessThanOrEqual(firstRow.frame.maxY, search.frame.minY, "the first board is not above the search field")
        let inSight = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'boards.row.'"))
            .allElementsBoundByIndex.filter(\.isHittable).map(\.frame.minY)
        let lastInSight = try XCTUnwrap(inSight.max(), "no board row is in sight")
        XCTAssertLessThan(lastInSight, search.frame.minY, "a board row in sight starts below the search field")
        XCTAssertLessThan(lastInSight, plus.frame.minY, "a board row in sight starts below the +")

        // With the keyboard up the row stays in reach: the field and the "+" sit over the keyboard.
        search.tap()
        let keyboard = app.keyboards.firstMatch
        // (A simulator with a Mac keyboard joined shows no keyboard on screen: then there is nothing to be over.)
        if keyboard.waitForExistence(timeout: 5) {
            XCTAssertLessThanOrEqual(search.frame.maxY, keyboard.frame.minY, "the keyboard covers the search field")
            XCTAssertLessThanOrEqual(plus.frame.maxY, keyboard.frame.minY, "the keyboard covers the +")
            XCTAssertTrue(plus.isHittable, "the + cannot be pressed with the keyboard up")
        }
        #else
        throw XCTSkip("The thumb row is the iPhone's layout only.")
        #endif
    }
}
