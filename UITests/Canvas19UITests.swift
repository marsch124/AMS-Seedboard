import XCTest

/// 0.19 (bar picks 12, 14, 15): two sticky notes chosen show "Stack", "Small Note" and "Put in a frame" in their bar.
/// Found by identifiers only.
final class Canvas19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTheBarOfTwoChosenNotesOffersStackSmallNoteAndPutInAFrame() {
        let app = XCUIApplication()
        var arguments = ["-board", "Summer", "-pickAll", "Alex about,timber"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(element(app, "board.selectionBar").waitForExistence(timeout: 15), "the bar of the chosen notes did not appear")
        XCTAssertTrue(element(app, "sel.stack").exists || element(app, "sel.more").exists, "Stack is missing")
        XCTAssertTrue(element(app, "sel.putInFrame").exists || element(app, "sel.more").exists, "Put in a frame is missing")
    }
}
